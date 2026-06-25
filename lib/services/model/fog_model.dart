import 'dart:typed_data';

import '../../data/models/fog_prediction.dart';

/// Seam #2 — the freezing-of-gait predictor.
///
/// Takes one sliding window and returns a [FogPrediction]. Implementations:
///   - MockFogModel   : scripted/random states so the UI reacts now.
///   - TfliteFogModel : loads a .tflite via tflite_flutter (M4).
///
/// Input contract (see sensor_schema.dart): a Float32List of
/// windowSize * featureCount values, row-major, canonical column order.
abstract class FogModel {
  /// Expected window length in timesteps (120).
  int get windowSize;

  /// Expected features per timestep (24).
  int get featureCount;

  /// Run inference once every [stepSize] new samples (sliding window hop).
  int get stepSize;

  /// Load weights / warm up. Call once before [predict].
  Future<void> load();

  /// Run inference over one flattened window. Async so a heavy backend can
  /// run on a background isolate without blocking the sample-ingestion loop
  /// (real-time sensor processing, e.g. cadence step detection, shares the
  /// main isolate and must not stall while inference runs).
  Future<FogPrediction> predict(Float32List window);

  /// Release native resources.
  Future<void> dispose();
}
