import 'dart:async';
import 'dart:typed_data';

import '../../core/sensor_schema.dart';
import '../../data/models/imu_sample.dart';
import '../../data/models/sensor_status.dart';
import 'arduino_ble_service.dart';
import 'sensor_source.dart';

/// Real [SensorSource] for the FoG walking session — backed by the single
/// back-mounted Arduino accelerometer (the only sensor location actually
/// wired up so far; ankles are stubbed "connected" since this mode doesn't
/// use them).
///
/// Emits 3-feature [ImuSample]s (accX, accY, accZ — used as the model's
/// AccV/AccML/AccAP) from [ArduinoBleService.readings]; gyro is dropped since
/// the back-sensor FoG model was trained on accelerometer only.
class ArduinoBackSensorSource implements SensorSource {
  ArduinoBackSensorSource(this._ble);

  final ArduinoBleService _ble;

  final _samples = StreamController<ImuSample>.broadcast();
  final _status = StreamController<SensorStatusMap>.broadcast();

  StreamSubscription? _bleChangeSub;
  StreamSubscription? _readingsSub;
  final _stopwatch = Stopwatch();

  @override
  Set<SensorLocation> get expectedLocations => {SensorLocation.lowerBack};

  @override
  Stream<ImuSample> get samples => _samples.stream;

  @override
  Stream<SensorStatusMap> get status => _status.stream;

  @override
  SensorStatusMap get statusNow => _statusFromBle();

  SensorStatusMap _statusFromBle() {
    final lowerBackState = switch (_ble.state) {
      ArduinoBleState.connected => SensorConnState.connected,
      ArduinoBleState.connecting || ArduinoBleState.scanning =>
        SensorConnState.pairing,
      ArduinoBleState.disconnected => SensorConnState.notConnected,
    };
    // Honest reporting: only the back sensor is real hardware. The ankles
    // aren't wired, so they show as not connected rather than falsely "ready".
    // Session readiness gates on [expectedLocations] (just the back sensor).
    return SensorStatusMap({
      SensorLocation.lowerBack: lowerBackState,
      SensorLocation.ankleLeft: SensorConnState.notConnected,
      SensorLocation.ankleRight: SensorConnState.notConnected,
    });
  }

  void _emitStatus() => _status.add(_statusFromBle());

  @override
  Future<void> connect(SensorLocation location) async {
    if (location != SensorLocation.lowerBack) return;
    if (_ble.state == ArduinoBleState.connected) return;

    _bleChangeSub ??= _ble.onChange.listen((_) => _emitStatus());

    await _ble.startScan();

    // ArduinoBleService already filters scan results to the Nano 33 BLE
    // (by advertised service UUID or recognisable name), so connect to the
    // first match. If none, _ble surfaces "no device found" via onChange.
    if (_ble.scanResults.isEmpty) return;
    await _ble.connect(_ble.scanResults.first.device);
  }

  @override
  Future<void> connectAll() => connect(SensorLocation.lowerBack);

  @override
  Future<void> start() async {
    _stopwatch
      ..reset()
      ..start();
    _readingsSub?.cancel();
    _readingsSub = _ble.readings.listen((r) {
      _samples.add(ImuSample(
        tMillis: _stopwatch.elapsedMilliseconds,
        features: Float32List.fromList([r.accX, r.accY, r.accZ]),
      ));
    });
  }

  @override
  Future<void> stop() async {
    await _readingsSub?.cancel();
    _readingsSub = null;
    _stopwatch.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _bleChangeSub?.cancel();
    await _samples.close();
    await _status.close();
  }
}
