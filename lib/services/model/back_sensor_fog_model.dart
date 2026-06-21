import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../../data/models/fog_prediction.dart';
import 'fog_model.dart';

/// On-device FoG inference for the single back-mounted Arduino accelerometer.
///
/// Mirrors not_overwritten/Transformer_BiLSTM4.py's preprocessing exactly:
/// raw (AccV, AccML, AccAP) -> + jerk (3) -> + FFT magnitude (3) = 9 channels,
/// over a 256-sample (2 s @ 128 Hz in training) window.
///
/// The bundled .tflite was re-exported from best_model4.keras with
/// `unroll=True` on both Bidirectional LSTM layers so it runs on the
/// standard mobile interpreter — the original export needed TF Select/Flex
/// ops (FlexTensorListReserve), which tflite_flutter can't load.
class BackSensorFogModel implements FogModel {
  BackSensorFogModel({this.thresholds = const FogThresholds()});

  final FogThresholds thresholds;
  Interpreter? _interpreter;

  static const _modelAsset = 'assets/models/fog_model_back.tflite';
  static const int _rawChannels = 3; // AccV, AccML, AccAP
  static const int _totalChannels = 9; // raw + jerk + fft magnitude

  @override
  int get windowSize => 256;

  @override
  int get featureCount => _rawChannels;

  @override
  int get stepSize => 64; // re-predict every 64 new samples (~4x/window)

  @override
  Future<void> load() async {
    _interpreter = await Interpreter.fromAsset(_modelAsset);
  }

  @override
  FogPrediction predict(Float32List window) {
    assert(
      window.length == windowSize * featureCount,
      'window must be ${windowSize * featureCount} floats (raw AccV/AccML/AccAP)',
    );

    final augmented = _augment(window);

    final inputTensor = [
      List.generate(
        windowSize,
        (t) => List.generate(
            _totalChannels, (f) => augmented[t * _totalChannels + f]),
      ),
    ];
    final outputTensor = [List.filled(1, 0.0)];

    _interpreter!.run(inputTensor, outputTensor);

    final prob = (outputTensor[0][0] as num).toDouble().clamp(0.0, 1.0);
    return FogPrediction(
      fogProbability: prob,
      state: thresholds.classify(prob),
      confidence: 1.0,
    );
  }

  /// raw(3) -> raw(3) + jerk(3) + fftMagnitude(3) per timestep, replicating
  /// add_jerk + add_fft_features from Transformer_BiLSTM4.py.
  Float32List _augment(Float32List raw) {
    final t = windowSize;
    final out = Float32List(t * _totalChannels);

    // Raw + jerk. np.diff(..., prepend=X[:, :1, :]) makes jerk[0] = 0.
    for (var i = 0; i < t; i++) {
      for (var c = 0; c < _rawChannels; c++) {
        final v = raw[i * _rawChannels + c];
        out[i * _totalChannels + c] = v;
        final prev = i == 0 ? v : raw[(i - 1) * _rawChannels + c];
        out[i * _totalChannels + _rawChannels + c] = v - prev;
      }
    }

    // FFT magnitude per channel, resampled from T//2+1 bins back to T —
    // matches np.linspace(0, half-1, T).astype(int) index mapping.
    final half = t ~/ 2 + 1;
    for (var c = 0; c < _rawChannels; c++) {
      final re = Float64List(t);
      for (var i = 0; i < t; i++) {
        re[i] = raw[i * _rawChannels + c];
      }
      final mag = _rfftMagnitude(re);
      for (var i = 0; i < t; i++) {
        final idx = (i * (half - 1) / (t - 1)).floor();
        out[i * _totalChannels + 2 * _rawChannels + c] = mag[idx];
      }
    }

    return out;
  }

  /// Real-input FFT magnitude via radix-2 Cooley-Tukey. [signal.length] must
  /// be a power of two. Returns the first n/2+1 magnitude bins (rfft).
  static List<double> _rfftMagnitude(Float64List signal) {
    final n = signal.length;
    final re = Float64List.fromList(signal);
    final im = Float64List(n);
    _fftInPlace(re, im);
    final half = n ~/ 2 + 1;
    return List<double>.generate(
        half, (i) => math.sqrt(re[i] * re[i] + im[i] * im[i]));
  }

  static void _fftInPlace(Float64List re, Float64List im) {
    final n = re.length;
    for (var i = 1, j = 0; i < n; i++) {
      var bit = n >> 1;
      while (j & bit != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (var len = 2; len <= n; len <<= 1) {
      final half = len >> 1;
      final ang = -2 * math.pi / len;
      final wRe = math.cos(ang);
      final wIm = math.sin(ang);
      for (var i = 0; i < n; i += len) {
        var curRe = 1.0, curIm = 0.0;
        for (var k = 0; k < half; k++) {
          final uRe = re[i + k], uIm = im[i + k];
          final vRe = re[i + k + half] * curRe - im[i + k + half] * curIm;
          final vIm = re[i + k + half] * curIm + im[i + k + half] * curRe;
          re[i + k] = uRe + vRe;
          im[i + k] = uIm + vIm;
          re[i + k + half] = uRe - vRe;
          im[i + k + half] = uIm - vIm;
          final nextRe = curRe * wRe - curIm * wIm;
          final nextIm = curRe * wIm + curIm * wRe;
          curRe = nextRe;
          curIm = nextIm;
        }
      }
    }
  }

  @override
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }
}
