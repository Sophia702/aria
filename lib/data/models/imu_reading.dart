/// One sample from the Arduino Nano 33 BLE IMU.
/// [accX/Y/Z] in g, [gyroX/Y/Z] in °/s.
class ImuReading {
  final double accX, accY, accZ;
  final double gyroX, gyroY, gyroZ;

  const ImuReading({
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
  });
}
