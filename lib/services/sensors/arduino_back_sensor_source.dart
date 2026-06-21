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
/// Board is mounted vertically. Emits 3-feature [ImuSample]s in
/// [AccV, AccML, AccAP] order — [r.accY, r.accX, r.accZ] from
/// [ArduinoBleService.readings] — matching the back-sensor FoG model's
/// trained axis convention. Gyro is dropped since that model was trained on
/// accelerometer only.
///
/// If the board is remounted again, re-derive this mapping: read live
/// accX/Y/Z at rest (the axis near ±1g is AccV) and while tilting forward
/// (the axis that stays flat is AccML; the one that shifts with AccV is
/// AccAP).
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
    // Ankles aren't part of this real flow — report them pre-connected so
    // SensorStatusMap.allConnected gates only on the real back sensor.
    return SensorStatusMap({
      SensorLocation.lowerBack: lowerBackState,
      SensorLocation.ankleLeft: SensorConnState.connected,
      SensorLocation.ankleRight: SensorConnState.connected,
    });
  }

  void _emitStatus() => _status.add(_statusFromBle());

  @override
  Future<void> connect(SensorLocation location) async {
    if (location != SensorLocation.lowerBack) return;
    if (_ble.state == ArduinoBleState.connected) return;

    _bleChangeSub ??= _ble.onChange.listen((_) => _emitStatus());

    await _ble.startScan();

    final match = _ble.scanResults.where((r) => r.advertisementData.serviceUuids
        .any((u) => u.str.toLowerCase() == ArduinoBleService.serviceUuid));
    if (match.isEmpty) {
      // _ble surfaces "no device found" via its own errorMessage/onChange;
      // nothing else to do here.
      return;
    }
    await _ble.connect(match.first.device);
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
        // Vertical-mounted board (confirmed live on-device): Y reads ~1g at
        // rest (AccV); a forward tilt shifts gravity from Y into Z while X
        // stays flat, so Z is fore-aft (AccAP) and X is side-to-side (AccML).
        features: Float32List.fromList([r.accY, r.accX, r.accZ]),
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
