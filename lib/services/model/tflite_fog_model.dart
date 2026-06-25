import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/sensor_schema.dart';
import '../../data/models/fog_prediction.dart';
import 'fog_model.dart';

/// On-device FoG inference via tflite_flutter.
///
/// ## Setup (one-time, from Colab after training):
///   1. Run export_model.py in Colab — saves fog_model.tflite.
///   2. Drop fog_model.tflite into assets/models/.
///   3. In providers.dart swap MockFogModel → TfliteFogModel.
///
/// ## Normalization (per-subject):
///   prepare_data.py uses StandardScaler per subject. Call [setNormParams]
///   with stats computed from the baseline walk before the first real session.
///   Without it, raw values are passed through (predictions will be off).
class TfliteFogModel implements FogModel {
  TfliteFogModel({this.thresholds = const FogThresholds()});

  final FogThresholds thresholds;
  Interpreter? _interpreter;
  Float32List? _mean;
  Float32List? _std;

  static const _modelAsset = 'assets/models/fog_model.tflite';

  @override
  int get windowSize => kWindowSize;

  @override
  int get featureCount => kFeatureCount;

  @override
  int get stepSize => kStepSize;

  /// Call this with stats from [computeNormParams] after the baseline walk.
  void setNormParams(Float32List mean, Float32List std) {
    assert(mean.length == kFeatureCount && std.length == kFeatureCount);
    _mean = mean;
    _std = std;
  }

  @override
  Future<void> load() async {
    _interpreter = await Interpreter.fromAsset(_modelAsset);
  }

  @override
  Future<FogPrediction> predict(Float32List window) async {
    assert(
      window.length == windowSize * featureCount,
      'window must be ${windowSize * featureCount} floats',
    );

    final input = _normalize(window);

    // [1, windowSize, featureCount]
    final inputTensor = [
      List.generate(
        windowSize,
        (t) => List.generate(featureCount, (f) => input[t * featureCount + f]),
      ),
    ];
    // [1, 1] — single sigmoid output
    final outputTensor = [List.filled(1, 0.0)];

    _interpreter!.run(inputTensor, outputTensor);

    final prob = (outputTensor[0][0] as num).toDouble().clamp(0.0, 1.0);
    return FogPrediction(
      fogProbability: prob,
      state: thresholds.classify(prob),
      confidence: 1.0,
    );
  }

  Float32List _normalize(Float32List window) {
    final mean = _mean;
    final std = _std;
    if (mean == null || std == null) return window;
    final out = Float32List(window.length);
    for (var i = 0; i < window.length; i++) {
      final col = i % featureCount;
      final s = std[col];
      out[i] = s > 1e-8 ? (window[i] - mean[col]) / s : 0.0;
    }
    return out;
  }

  @override
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }
}

/// Computes per-subject StandardScaler mean/std from raw sensor windows
/// collected during the baseline walk. Pass the result to
/// [TfliteFogModel.setNormParams] before starting a real session.
({Float32List mean, Float32List std}) computeNormParams(
    List<Float32List> windows, int featureCount) {
  final n = windows.length * (windows.first.length ~/ featureCount);
  final mean = Float32List(featureCount);
  final std = Float32List(featureCount);

  for (final w in windows) {
    for (var i = 0; i < w.length; i++) {
      mean[i % featureCount] += w[i];
    }
  }
  for (var f = 0; f < featureCount; f++) {
    mean[f] /= n;
  }

  for (final w in windows) {
    for (var i = 0; i < w.length; i++) {
      final d = w[i] - mean[i % featureCount];
      std[i % featureCount] += d * d;
    }
  }
  for (var f = 0; f < featureCount; f++) {
    final variance = std[f] / n;
    std[f] = variance > 0 ? math.sqrt(variance) : 1.0;
  }

  return (mean: mean, std: std);
}
