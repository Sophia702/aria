import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../../data/models/fog_prediction.dart';
import 'fog_model.dart';

const int _kWindowSize = 256;
const int _kRawChannels = 3; // AccV, AccML, AccAP
const int _kTotalChannels = 9; // raw + jerk + fft magnitude

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
///
/// Augmentation (jerk/FFT, pure Dart) + the native interpreter call together
/// took 100-240ms on-device — long enough to stall the main isolate's event
/// loop mid-walk, which corrupted real-time sensor processing sharing that
/// isolate (e.g. cadence step timing, which timestamps via DateTime.now() at
/// processing time). Both run on a persistent background isolate instead,
/// using the same native-pointer trick tflite_flutter's own
/// IsolateInterpreter uses: the interpreter's native address is a plain int,
/// reconstructable via Interpreter.fromAddress() from any isolate in the
/// same process, since the actual TFLite state lives in native memory.
class BackSensorFogModel implements FogModel {
  BackSensorFogModel({this.thresholds = const FogThresholds()});

  final FogThresholds thresholds;
  Interpreter? _interpreter;
  Isolate? _isolate;
  SendPort? _workerPort;
  final ReceivePort _mainPort = ReceivePort();
  StreamSubscription? _mainPortSub;
  Completer<double>? _pending;
  Future<void> _inFlight = Future.value();

  static const _modelAsset = 'assets/models/fog_model_back.tflite';

  @override
  int get windowSize => _kWindowSize;

  @override
  int get featureCount => _kRawChannels;

  @override
  int get stepSize => 64; // re-predict every 64 new samples (~4x/window)

  @override
  Future<void> load() async {
    _interpreter = await Interpreter.fromAsset(_modelAsset);

    final readyCompleter = Completer<SendPort>();
    _mainPortSub = _mainPort.listen((message) {
      if (message is SendPort) {
        readyCompleter.complete(message);
      } else if (message is double) {
        _pending?.complete(message);
        _pending = null;
      }
    });
    _isolate = await Isolate.spawn(_isolateMain, _mainPort.sendPort);
    _workerPort = await readyCompleter.future;
  }

  @override
  Future<FogPrediction> predict(Float32List window) async {
    assert(
      window.length == windowSize * featureCount,
      'window must be ${windowSize * featureCount} floats (raw AccV/AccML/AccAP)',
    );
    final interpreter = _interpreter;
    final workerPort = _workerPort;
    if (interpreter == null || workerPort == null) {
      // load() wasn't awaited before predict() — shouldn't happen, but fail
      // soft rather than crash mid-walk.
      return FogPrediction(
          fogProbability: 0, state: thresholds.classify(0), confidence: 0);
    }

    // Chain behind any still-in-flight request rather than overlap two
    // requests on the single response port (which has no way to tell two
    // outstanding replies apart). Inference is far faster than the interval
    // between predict() calls in practice, so this rarely actually waits.
    final resultFuture =
        _inFlight.then((_) => _runOnWorker(workerPort, interpreter.address, window));
    _inFlight = resultFuture.then((_) {}, onError: (_) {});

    final prob = (await resultFuture).clamp(0.0, 1.0);
    return FogPrediction(
      fogProbability: prob,
      state: thresholds.classify(prob),
      confidence: 1.0,
    );
  }

  Future<double> _runOnWorker(
      SendPort workerPort, int interpreterAddress, Float32List window) async {
    final completer = Completer<double>();
    _pending = completer;
    workerPort.send(_PredictRequest(interpreterAddress, window));
    return completer.future;
  }

  @override
  Future<void> dispose() async {
    await _mainPortSub?.cancel();
    _mainPort.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _interpreter?.close();
    _interpreter = null;
  }
}

class _PredictRequest {
  final int address;
  final Float32List window;
  const _PredictRequest(this.address, this.window);
}

/// Entry point for the background isolate. Runs the full augmentation +
/// inference pipeline so neither step touches the main isolate.
void _isolateMain(SendPort mainSendPort) {
  final port = ReceivePort();
  mainSendPort.send(port.sendPort);

  port.listen((message) {
    if (message is! _PredictRequest) return;
    final interpreter = Interpreter.fromAddress(message.address);
    final augmented = _augment(message.window);

    final inputTensor = [
      List.generate(
        _kWindowSize,
        (t) =>
            List.generate(_kTotalChannels, (f) => augmented[t * _kTotalChannels + f]),
      ),
    ];
    final outputTensor = [List.filled(1, 0.0)];
    interpreter.run(inputTensor, outputTensor);

    final prob = (outputTensor[0][0] as num).toDouble();
    mainSendPort.send(prob);
  });
}

/// raw(3) -> raw(3) + jerk(3) + fftMagnitude(3) per timestep, replicating
/// add_jerk + add_fft_features from Transformer_BiLSTM4.py.
Float32List _augment(Float32List raw) {
  const t = _kWindowSize;
  final out = Float32List(t * _kTotalChannels);

  // Raw + jerk. np.diff(..., prepend=X[:, :1, :]) makes jerk[0] = 0.
  for (var i = 0; i < t; i++) {
    for (var c = 0; c < _kRawChannels; c++) {
      final v = raw[i * _kRawChannels + c];
      out[i * _kTotalChannels + c] = v;
      final prev = i == 0 ? v : raw[(i - 1) * _kRawChannels + c];
      out[i * _kTotalChannels + _kRawChannels + c] = v - prev;
    }
  }

  // FFT magnitude per channel, resampled from T//2+1 bins back to T —
  // matches np.linspace(0, half-1, T).astype(int) index mapping.
  const half = t ~/ 2 + 1;
  for (var c = 0; c < _kRawChannels; c++) {
    final re = Float64List(t);
    for (var i = 0; i < t; i++) {
      re[i] = raw[i * _kRawChannels + c];
    }
    final mag = _rfftMagnitude(re);
    for (var i = 0; i < t; i++) {
      final idx = (i * (half - 1) / (t - 1)).floor();
      out[i * _kTotalChannels + 2 * _kRawChannels + c] = mag[idx];
    }
  }

  return out;
}

/// Real-input FFT magnitude via radix-2 Cooley-Tukey. [signal.length] must
/// be a power of two. Returns the first n/2+1 magnitude bins (rfft).
List<double> _rfftMagnitude(Float64List signal) {
  final n = signal.length;
  final re = Float64List.fromList(signal);
  final im = Float64List(n);
  _fftInPlace(re, im);
  final half = n ~/ 2 + 1;
  return List<double>.generate(
      half, (i) => math.sqrt(re[i] * re[i] + im[i] * im[i]));
}

void _fftInPlace(Float64List re, Float64List im) {
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
