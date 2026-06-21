import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/imu_reading.dart';

/// BLE connection state for the Arduino IMU sensor.
enum ArduinoBleState { disconnected, scanning, connecting, connected }

/// Service that scans for, connects to, and streams IMU data from an
/// Arduino Nano 33 BLE. Flash the following sketch to your board:
///   https://github.com/Sophia702/M1-Project (see README for sketch)
///
/// Your Arduino sketch must advertise:
///   Service UUID : 19b10000-e8f2-537e-4f6c-d104768a1214
///   Char UUID    : 19b10001-e8f2-537e-4f6c-d104768a1214
///
/// Each BLE notification is 24 bytes: 6 × float32 little-endian
///   bytes  0–3  : accel X (g)
///   bytes  4–7  : accel Y (g)
///   bytes  8–11 : accel Z (g)
///   bytes 12–15 : gyro  X (°/s)
///   bytes 16–19 : gyro  Y (°/s)
///   bytes 20–23 : gyro  Z (°/s)
class ArduinoBleService {
  static const _serviceUuid = '19b10000-e8f2-537e-4f6c-d104768a1214';
  static const _imuCharUuid = '19b10001-e8f2-537e-4f6c-d104768a1214';

  /// Public alias so other services (e.g. ArduinoBackSensorSource) can filter
  /// scan results without duplicating the literal UUID.
  static const String serviceUuid = _serviceUuid;

  ArduinoBleState _state = ArduinoBleState.disconnected;
  ArduinoBleState get state => _state;

  final List<ScanResult> _scanResults = [];
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);

  String? _connectedName;
  String? get connectedName => _connectedName;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final _onChange = StreamController<void>.broadcast();
  /// Fires whenever any service state changes (state, scanResults, error).
  Stream<void> get onChange => _onChange.stream;

  final _imuController = StreamController<ImuReading>.broadcast();
  Stream<ImuReading> get readings => _imuController.stream;

  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _imuSub;

  // ── Scan ─────────────────────────────────────────────────────────────────

  Future<void> startScan() async {
    if (_state != ArduinoBleState.disconnected) return;

    if (!await _requestPermissions()) {
      _errorMessage = 'Bluetooth permission denied. Go to Settings → Apps → aria → Permissions and enable Nearby devices.';
      _notify();
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _errorMessage = 'Bluetooth is off. Please enable it and try again.';
      _notify();
      return;
    }

    _scanResults.clear();
    _errorMessage = null;
    _setState(ArduinoBleState.scanning);

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      _scanResults
        ..clear()
        ..addAll(results);
      _notify();
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      await FlutterBluePlus.isScanning.where((v) => !v).first;
    } catch (e) {
      _errorMessage = 'Scan failed: $e';
      _notify();
    } finally {
      _scanSub?.cancel();
      if (_state == ArduinoBleState.scanning) {
        _setState(ArduinoBleState.disconnected);
      }
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  // ── Connect ──────────────────────────────────────────────────────────────

  Future<void> connect(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    _errorMessage = null;
    _setState(ArduinoBleState.connecting);

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      _device = device;
      _connectedName = device.platformName.isNotEmpty
          ? device.platformName
          : 'Arduino Nano 33 BLE';

      _connSub?.cancel();
      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected &&
            _state == ArduinoBleState.connected) {
          _imuSub?.cancel();
          _device = null;
          _connectedName = null;
          _setState(ArduinoBleState.disconnected);
        }
      });

      final services = await device.discoverServices();
      bool found = false;
      for (final svc in services) {
        if (svc.serviceUuid.str.toLowerCase() == _serviceUuid) {
          for (final chr in svc.characteristics) {
            if (chr.characteristicUuid.str.toLowerCase() == _imuCharUuid) {
              await chr.setNotifyValue(true);
              _imuSub = chr.onValueReceived.listen(_parsePacket);
              found = true;
            }
          }
        }
      }

      if (!found) {
        _errorMessage = 'IMU service not found. Check your Arduino sketch UUIDs.';
        await device.disconnect();
        _device = null;
        _setState(ArduinoBleState.disconnected);
        return;
      }

      _setState(ArduinoBleState.connected);
    } catch (e) {
      await device.disconnect().catchError((_) {});
      _device = null;
      _errorMessage = 'Connection failed: $e';
      _setState(ArduinoBleState.disconnected);
    }
  }

  Future<void> disconnect() async {
    _imuSub?.cancel();
    _connSub?.cancel();
    await _device?.disconnect().catchError((_) {});
    _device = null;
    _connectedName = null;
    _setState(ArduinoBleState.disconnected);
  }

  // ── Packet parsing ────────────────────────────────────────────────────────

  void _parsePacket(List<int> bytes) {
    if (bytes.length < 24) return;
    final bd = ByteData.sublistView(Uint8List.fromList(bytes));
    _imuController.add(ImuReading(
      accX: bd.getFloat32(0, Endian.little),
      accY: bd.getFloat32(4, Endian.little),
      accZ: bd.getFloat32(8, Endian.little),
      gyroX: bd.getFloat32(12, Endian.little),
      gyroY: bd.getFloat32(16, Endian.little),
      gyroZ: bd.getFloat32(20, Endian.little),
    ));
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<bool> _requestPermissions() async {
    if (Platform.isIOS) return true;
    // Android 12+ (API 31+): only BLUETOOTH_SCAN / BLUETOOTH_CONNECT needed.
    // Location is not required when the manifest uses neverForLocation.
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    return results.values.every((s) => s.isGranted || s.isLimited);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setState(ArduinoBleState s) {
    _state = s;
    _notify();
  }

  void _notify() => _onChange.add(null);

  Future<void> dispose() async {
    _scanSub?.cancel();
    _imuSub?.cancel();
    _connSub?.cancel();
    await _device?.disconnect().catchError((_) {});
    await _onChange.close();
    await _imuController.close();
  }
}
