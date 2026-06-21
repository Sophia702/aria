import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/fog_prediction.dart';
import '../../data/models/imu_sample.dart';
import '../../data/models/sensor_status.dart';
import '../../data/models/walk_session.dart';
import '../../data/persistence/app_prefs.dart';
import '../../providers/providers.dart';
import '../cadence/cadence_service.dart';
import '../cue/cue_engine.dart';
import '../intervention/intervention_manager.dart';
import '../model/fog_model.dart';
import '../sensors/arduino_ble_service.dart';
import '../sensors/sensor_source.dart';
import '../watch/watch_cadence_service.dart';
import 'ring_buffer.dart';
import 'session_state.dart';

/// Wires the whole pipeline and exposes a [SessionSnapshot] the UI reacts to:
///
///   SensorSource.samples -> WindowBuffer -> (every model.stepSize) FogModel.predict
///     -> FogState -> session-state transitions -> CueEngine (continuous) +
///        InterventionManager.
///
/// The UI never touches raw samples; it only reads the snapshot and calls the
/// command methods below. (Riverpod 3 `Notifier` — dependencies are resolved in
/// [build] via `ref`.)
class SessionController extends Notifier<SessionSnapshot> {
  late final SensorSource sensors;
  late final FogModel model;
  late final CueEngine cue;
  late final InterventionManager intervention;

  late WindowBuffer _window;
  StreamSubscription? _sampleSub;
  StreamSubscription? _interventionSub;

  // Live cadence sources (real steps/min) feeding the walking screen.
  StreamSubscription<double?>? _watchCadenceSub;
  StreamSubscription<double>? _imuCadenceSub;
  CadenceService? _imuCadence;

  // Non-null when the active beat is a synthesized click (BeatKind.click) —
  // the cue plays it audibly and re-tempos with live cadence. Null means a
  // music beat is active; WalkingScreen owns that audio and retempo itself,
  // so the cue stays silent (volume 0) but keeps running for ring/state sync.
  BeatSound? _activeSound;
  double _lastAppliedBpm = 0;
  static const double _retempoThresholdSpm = 4.0;

  int _sinceStep = 0;
  Timer? _ticker;
  Timer? _calibrationTimer;
  DateTime? _walkStart;
  static const Duration _calibrationDuration = Duration(seconds: 5);

  @override
  SessionSnapshot build() {
    sensors = ref.watch(sensorSourceProvider);
    model = ref.watch(fogModelProvider);
    cue = ref.watch(cueEngineProvider);
    intervention = ref.watch(interventionManagerProvider);

    // Sized from the active model — different sensor/model pairs use
    // different window/feature shapes (e.g. 256x3 for the back sensor).
    _window = WindowBuffer(
        windowSize: model.windowSize, featureCount: model.featureCount);

    _interventionSub = intervention.requests.listen(_onInterventionRequest);
    ref.onDispose(() {
      _sampleSub?.cancel();
      _interventionSub?.cancel();
      _ticker?.cancel();
      _calibrationTimer?.cancel();
      _stopLiveCadence();
    });

    return const SessionSnapshot();
  }

  // ── Live cadence ──────────────────────────────────────────────────────────
  // Show REAL steps/min during a walk, preferring the Arduino IMU (if the board
  // is connected) and otherwise the Apple Watch step cadence. Falls back to the
  // cue tempo when no real source is available.
  void _startLiveCadence() {
    final ble = ref.read(arduinoBleProvider);
    if (ble.state == ArduinoBleState.connected) {
      final cadence = CadenceService(ble);
      _imuCadence = cadence;
      cadence.start();
      _imuCadenceSub = cadence.onCadence.listen((spm) {
        if (spm > 0) _applyLiveCadence(spm);
      });
    }
    // Apple Watch cadence (iOS). Yields null when unavailable — harmless.
    _watchCadenceSub = WatchCadenceService.liveStream().listen((spm) {
      if (spm != null && spm > 0) _applyLiveCadence(spm);
    });
  }

  // Below this, the person has effectively stopped — treat it as a freeze
  // regardless of what the FoG model says, and surface the intervention.
  static const double _lowCadenceFreezeSpm = 25.0;

  void _applyLiveCadence(double spm) {
    if (state.state != SessionState.walkingNormal &&
        state.state != SessionState.intervention &&
        state.state != SessionState.calibrating) {
      return;
    }
    state = state.copyWith(stepsPerMin: spm);

    // During calibration we only measure — no retempo, no freeze-triggered
    // intervention yet (gait right at walk-start is naturally irregular).
    if (state.state == SessionState.calibrating) return;

    if (spm > 0 && spm < _lowCadenceFreezeSpm) {
      // Reuses the same debounced request pipeline as FoG predictions, so it
      // won't spam the UI while cadence stays low — one request per episode.
      intervention.onFogState(FogState.freezing);
    }

    // Only re-tempo on a noticeable pace change — same anti-jitter threshold
    // the Cadence Tracker used. A click beat re-tempos the cue directly
    // (glitch-free via CueEngine's speed-based retempo); a music beat is
    // retempoed by WalkingScreen itself, which also watches stepsPerMin.
    if ((spm - _lastAppliedBpm).abs() < _retempoThresholdSpm) return;
    _lastAppliedBpm = spm;
    if (_activeSound != null) {
      cue.setTempo(spm);
    }
    state = state.copyWith(bpm: spm);
  }

  /// Calibration ends: lock in the measured cadence immediately rather than
  /// waiting for the next ≥4 SPM threshold crossing.
  void _endCalibration() {
    if (state.state != SessionState.calibrating) return;
    state = state.copyWith(state: SessionState.walkingNormal);
    final spm = state.stepsPerMin;
    if (spm > 0) {
      _lastAppliedBpm = spm;
      if (_activeSound != null) cue.setTempo(spm);
      state = state.copyWith(bpm: spm);
    }
  }

  void _stopLiveCadence() {
    _watchCadenceSub?.cancel();
    _watchCadenceSub = null;
    _imuCadenceSub?.cancel();
    _imuCadenceSub = null;
    _imuCadence?.dispose();
    _imuCadence = null;
  }

  /// Begin a walking session. [bpm] is the baseline cadence from calibration
  /// (steps/min); for M1 it's passed in directly. [sound] is non-null for a
  /// click beat (cue plays it audibly); null means a music beat is active
  /// (WalkingScreen owns that audio, so the cue is muted but kept running for
  /// ring/state sync).
  Future<void> startSession({double bpm = 100, BeatSound? sound}) async {
    _window.clear();
    _sinceStep = 0;
    _activeSound = sound;
    _lastAppliedBpm = bpm;

    await model.load();

    // Make sure the sensors this source actually needs are connected (the back
    // sensor for the real flow; the mock connects instantly). Gating on
    // expectedLocations avoids waiting on ankles that aren't real hardware.
    final ready = sensors.expectedLocations.every(
        (l) => sensors.statusNow.of(l) == SensorConnState.connected);
    if (!ready) {
      await sensors.connectAll();
    }

    await cue.init();
    if (sound != null) await cue.setSound(sound);
    await cue.startCue(bpm: bpm);
    await cue.setVolume(sound != null ? await AppPrefs.cueVolume() / 100.0 : 0);
    await sensors.start();
    _sampleSub = sensors.samples.listen(_onSample);

    // Beat plays immediately at the chosen tempo; for the first
    // [_calibrationDuration] we just measure real cadence — no retempo, no
    // freeze-triggered intervention — so a few seconds of step intervals can
    // settle before anything reacts to them.
    state = state.copyWith(
      state: SessionState.calibrating,
      fogState: FogState.normal,
      fogProbability: 0,
      bpm: bpm,
      stepsPerMin: bpm,
      elapsed: Duration.zero,
      freezesEased: 0,
      cuePlaying: true,
    );

    // Walk timer ticks independently of sensor samples, so the elapsed time
    // is always correct even when no hardware is streaming.
    _walkStart = DateTime.now();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final start = _walkStart;
      if (start != null) {
        state = state.copyWith(elapsed: DateTime.now().difference(start));
      }
    });

    _startLiveCadence();

    _calibrationTimer?.cancel();
    _calibrationTimer = Timer(_calibrationDuration, _endCalibration);
  }

  /// Switch the active beat mid-walk (from the walking screen's beat picker).
  /// [sound] non-null switches to a click beat (cue plays it audibly);
  /// null switches to a music beat (cue goes silent; WalkingScreen plays it).
  Future<void> changeTempo(double bpm, {BeatSound? sound}) async {
    _activeSound = sound;
    _lastAppliedBpm = bpm;
    if (sound != null) await cue.setSound(sound);
    await cue.setTempo(bpm);
    await cue.setVolume(sound != null ? await AppPrefs.cueVolume() / 100.0 : 0);
    state = state.copyWith(bpm: bpm);
  }

  void _onSample(ImuSample sample) {
    _window.add(sample.features);
    _sinceStep++;

    if (_window.isFull && _sinceStep >= model.stepSize) {
      _sinceStep = 0;
      _applyPrediction(model.predict(_window.snapshot()));
    }
  }

  void _applyPrediction(FogPrediction p) {
    // FoG predictions only drive the ring colour / status pill here — the
    // intervention screen is triggered solely by low live cadence (see
    // _applyLiveCadence), not by the model's verdict.
    //
    // Don't overwrite the screen while an intervention is showing or
    // calibration is still running.
    final nextSessionState = switch (state.state) {
      SessionState.intervention => SessionState.intervention,
      SessionState.calibrating => SessionState.calibrating,
      _ => SessionState.walkingNormal,
    };

    state = state.copyWith(
      state: nextSessionState,
      fogState: p.state,
      fogProbability: p.fogProbability,
    );
  }

  void _onInterventionRequest(InterventionRequest req) {
    // Surface the intervention flow. The cue KEEPS PLAYING — rhythmic auditory
    // cueing is itself a strategy to overcome a freeze.
    state = state.copyWith(state: SessionState.intervention);
  }

  /// Called by the intervention UI with the user's choice.
  Future<InterventionResult> resolveIntervention(InterventionAction action) async {
    final result = await intervention.resolve(action);
    final eased =
        result.resumeWalking ? state.freezesEased + 1 : state.freezesEased;
    state = state.copyWith(
      state: SessionState.walkingNormal,
      fogState: FogState.normal,
      fogProbability: 0,
      freezesEased: eased,
    );
    return result;
  }

  /// End the walk; snapshot stats remain for the summary screen.
  Future<void> endSession() async {
    await _sampleSub?.cancel();
    _sampleSub = null;
    _ticker?.cancel();
    _ticker = null;
    _calibrationTimer?.cancel();
    _calibrationTimer = null;
    _stopLiveCadence();
    await sensors.stop();
    await cue.stopCue();

    // Persist the completed walk so Home / Progress / Summary show real data.
    if (state.elapsed.inSeconds >= 5) {
      final minutes = state.elapsed.inSeconds / 60.0;
      await ref.read(sessionHistoryProvider.notifier).record(WalkSession(
            startedAtMs: DateTime.now().millisecondsSinceEpoch -
                state.elapsed.inMilliseconds,
            durationSeconds: state.elapsed.inSeconds,
            steps: (state.stepsPerMin * minutes).round(),
            avgCadence: state.stepsPerMin,
            freezesEased: state.freezesEased,
          ));
    }

    state = state.copyWith(state: SessionState.ended, cuePlaying: false);
  }

  /// Reset back to idle (e.g. after the summary screen).
  void reset() => state = const SessionSnapshot();
}
