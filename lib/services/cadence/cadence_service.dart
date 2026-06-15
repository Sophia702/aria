import 'dart:async';
import 'dart:collection';
import 'dart:math';

import '../../data/models/imu_reading.dart';
import '../sensors/arduino_ble_service.dart';

/// Detects steps from the Arduino accelerometer stream and estimates
/// walking cadence (steps per minute).
///
/// Algorithm: EMA of acceleration magnitude tracks gravity + orientation;
/// a rising edge above [_threshold] g (with hysteresis + dead-time) fires
/// one step event per footfall.
class CadenceService {
  CadenceService(this._ble);

  final ArduinoBleService _ble;

  // ── Detection tuning ──────────────────────────────────────────────────────
  static const double _alpha = 0.10;       // EMA speed (tracks gravity drift)
  static const double _threshold = 0.25;   // g above EMA to trigger step
  static const double _hysteresis = 0.15;  // g below EMA to reset trigger (wider band = fewer false resets)
  static const int _deadTimeMs = 400;      // min ms between steps (~150 SPM max, eliminates double-fire)
  static const int _windowSize = 6;        // inter-step intervals to average

  // ── State ─────────────────────────────────────────────────────────────────
  double _ema = 1.0;
  bool _aboveThreshold = false;
  DateTime? _lastStep;
  final Queue<double> _intervals = Queue();
  double _currentCadence = 0;
  int _stepCount = 0;

  // ── Output ────────────────────────────────────────────────────────────────
  final _stepCtrl = StreamController<void>.broadcast();
  final _cadenceCtrl = StreamController<double>.broadcast();

  /// Fires on every detected step.
  Stream<void> get onStep => _stepCtrl.stream;

  /// Emits updated cadence (SPM) after each step once ≥2 intervals are known.
  Stream<double> get onCadence => _cadenceCtrl.stream;

  double get currentCadence => _currentCadence;
  int get stepCount => _stepCount;

  StreamSubscription<ImuReading>? _sub;
  bool _active = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void start() {
    if (_active) return;
    _reset();
    _active = true;
    _sub = _ble.readings.listen(_process);
  }

  void stop() {
    _active = false;
    _sub?.cancel();
    _sub = null;
  }

  void _reset() {
    _ema = 1.0;
    _aboveThreshold = false;
    _lastStep = null;
    _intervals.clear();
    _currentCadence = 0;
    _stepCount = 0;
  }

  void dispose() {
    stop();
    _stepCtrl.close();
    _cadenceCtrl.close();
  }

  // ── Signal processing ─────────────────────────────────────────────────────

  void _process(ImuReading r) {
    final mag = sqrt(r.accX * r.accX + r.accY * r.accY + r.accZ * r.accZ);
    _ema = _ema * (1 - _alpha) + mag * _alpha;
    final dev = mag - _ema;

    if (!_aboveThreshold && dev > _threshold) {
      _aboveThreshold = true;
      _tryFireStep();
    } else if (_aboveThreshold && dev < _hysteresis) {
      _aboveThreshold = false;
    }
  }

  void _tryFireStep() {
    final now = DateTime.now();
    final intervalMs =
        _lastStep == null ? null : now.difference(_lastStep!).inMilliseconds;

    if (intervalMs != null && intervalMs < _deadTimeMs) return;

    _stepCount++;
    _stepCtrl.add(null);

    if (intervalMs != null) {
      final sec = intervalMs / 1000.0;
      _intervals.addLast(sec);
      if (_intervals.length > _windowSize) _intervals.removeFirst();
      if (_intervals.length >= 2) {
        final avg = _intervals.fold(0.0, (s, v) => s + v) / _intervals.length;
        _currentCadence = 60.0 / avg;
        _cadenceCtrl.add(_currentCadence);
      }
    }

    _lastStep = now;
  }
}
