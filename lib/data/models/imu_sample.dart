import 'dart:typed_data';

/// One timestep of IMU data from a [SensorSource].
///
/// [features] length depends on the source/model pair in use — e.g. 18 for
/// the multi-location back+ankles schema (see sensor_schema.dart), or 3 for
/// the single back-sensor accelerometer schema. [WindowBuffer] validates the
/// length against the model it's feeding, not this class.
class ImuSample {
  /// Milliseconds since session start (monotonic), not wall-clock.
  final int tMillis;

  final Float32List features;

  ImuSample({required this.tMillis, required this.features});
}
