import '../../data/models/fog_prediction.dart';

/// Chosen before a walk starts (see ChooseModeScreen).
///   - [cadenceOnly]: just cadence tracking + beat sync — the FoG model never
///     loads or runs, so no model-driven status/intervention.
///   - [fogPrediction]: cadence tracking AND the back-sensor FoG model,
///     surfacing freeze predictions via the status pill and ring colour.
enum WalkMode { cadenceOnly, fogPrediction }

/// High-level session phase that drives screen routing.
///
/// M1 actively uses: idle, walkingNormal, intervention, ended.
/// The others are defined for the full machine (M2+): calibrating during the
/// baseline walk, choosingCue on the beat-picker, paused, and the discrete
/// preFreeze/frozen phases if we later route them to their own screens.
enum SessionState {
  idle,
  calibrating,
  choosingCue,
  walkingNormal,
  preFreeze,
  intervention,
  frozen,
  paused,
  ended,
}

/// Immutable snapshot the UI renders from. The UI reacts to THIS, never to raw
/// sensor data.
class SessionSnapshot {
  final WalkMode mode;
  final SessionState state;
  final FogState fogState; // colours the walking PulseRing
  final double fogProbability;
  final double stepsPerMin; // displayed cadence (= cue tempo in M1)
  final double bpm; // current cue tempo
  final Duration elapsed;
  final int freezesEased; // interventions resolved with "continue"
  final bool cuePlaying;

  const SessionSnapshot({
    this.mode = WalkMode.fogPrediction,
    this.state = SessionState.idle,
    this.fogState = FogState.normal,
    this.fogProbability = 0,
    this.stepsPerMin = 0,
    this.bpm = 0,
    this.elapsed = Duration.zero,
    this.freezesEased = 0,
    this.cuePlaying = false,
  });

  SessionSnapshot copyWith({
    WalkMode? mode,
    SessionState? state,
    FogState? fogState,
    double? fogProbability,
    double? stepsPerMin,
    double? bpm,
    Duration? elapsed,
    int? freezesEased,
    bool? cuePlaying,
  }) {
    return SessionSnapshot(
      mode: mode ?? this.mode,
      state: state ?? this.state,
      fogState: fogState ?? this.fogState,
      fogProbability: fogProbability ?? this.fogProbability,
      stepsPerMin: stepsPerMin ?? this.stepsPerMin,
      bpm: bpm ?? this.bpm,
      elapsed: elapsed ?? this.elapsed,
      freezesEased: freezesEased ?? this.freezesEased,
      cuePlaying: cuePlaying ?? this.cuePlaying,
    );
  }
}
