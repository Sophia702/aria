import 'dart:async';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../config.dart';
import 'voice_assistant.dart';

/// aria's hands-free voice agent with a natural, soft neural voice.
///
/// - SPEECH:  OpenAI text-to-speech (`gpt-4o-mini-tts`, voice "shimmer") streamed
///   to an mp3 and played via just_audio. Falls back to on-device flutter_tts if
///   the network/key is unavailable so the app never goes mute.
/// - HEARING: on-device speech_to_text tuned for natural, unhurried speech —
///   a long listen window that ends on a short silence (endpointing), so older
///   adults are never cut off mid-sentence.
class OpenAiVoiceAssistant implements VoiceAssistant {
  final SpeechToText _stt = SpeechToText();
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _fallbackTts = FlutterTts();
  bool _available = false;
  int _fileSeq = 0;

  // OpenAI TTS config.
  static const _ttsUrl = 'https://api.openai.com/v1/audio/speech';
  static const _ttsModel = 'gpt-4o-mini-tts';
  static const _ttsVoice = 'shimmer'; // soft, gentle female voice
  static const _ttsInstructions =
      'Speak in a warm, soft, gentle and caring tone — like a kind woman '
      'talking calmly and clearly to an older adult. Unhurried and reassuring, '
      'with natural, friendly inflection.';

  bool get _hasKey =>
      openAiApiKey.isNotEmpty && openAiApiKey != 'YOUR_OPENAI_API_KEY_HERE';

  @override
  bool get isAvailable => _available;

  @override
  Future<bool> init() async {
    _available = await _stt.initialize(
      onError: (e) {/* swallow; loop will retry */},
      onStatus: (_) {},
    );

    // Configure the on-device fallback voice (used only if OpenAI is unreachable).
    await _fallbackTts.setLanguage('en-US');
    await _fallbackTts.setSpeechRate(0.45);
    await _fallbackTts.setVolume(1.0);
    await _fallbackTts.awaitSpeakCompletion(true);
    if (Platform.isIOS) {
      await _fallbackTts.setSharedInstance(true);
      await _fallbackTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }
    return _available;
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    // Make sure the mic isn't capturing while we talk.
    if (_stt.isListening) await _stt.stop();

    if (_hasKey) {
      try {
        await _speakWithOpenAi(text);
        return;
      } catch (_) {
        // Network/key failure — fall through to on-device voice.
      }
    }
    await _speakWithFallback(text);
  }

  Future<void> _speakWithOpenAi(String text) async {
    final response = await http
        .post(
          Uri.parse(_ttsUrl),
          headers: {
            'Authorization': 'Bearer $openAiApiKey',
            'Content-Type': 'application/json',
          },
          body: _jsonBody(text),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception('TTS ${response.statusCode}');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/aria_tts_${_fileSeq++}.mp3');
    await file.writeAsBytes(response.bodyBytes, flush: true);

    await _player.stop();
    await _player.setFilePath(file.path);
    await _player.play(); // completes when playback reaches the end
    await _player.stop();
  }

  Future<void> _speakWithFallback(String text) async {
    await _fallbackTts.stop();
    await _fallbackTts.speak(text);
  }

  String _jsonBody(String text) {
    // Hand-built to avoid importing dart:convert twice; tiny and safe.
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
    final instr = _ttsInstructions.replaceAll('"', r'\"');
    return '{"model":"$_ttsModel","voice":"$_ttsVoice",'
        '"input":"$escaped","instructions":"$instr",'
        '"response_format":"mp3","speed":1.0}';
  }

  @override
  Future<String?> listenOnce({
    Duration listenFor = const Duration(seconds: 30),
  }) async {
    if (!_available) return null;
    final completer = Completer<String?>();

    await _stt.listen(
      onResult: (result) {
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        // Partial results let the recognizer track speech and fire a final
        // result after a natural pause, instead of a hard cut-off.
        partialResults: true,
        cancelOnError: true,
        // Dictation handles longer, free-form sentences far better than the
        // short-command "confirmation" mode.
        listenMode: ListenMode.dictation,
        listenFor: listenFor,
        // End the turn ~2.5s after the user stops talking — generous enough
        // that slow or paused speech isn't truncated.
        pauseFor: const Duration(milliseconds: 2500),
      ),
    );

    // Safety net: if no final result arrives, return whatever was captured.
    Timer(listenFor + const Duration(milliseconds: 800), () async {
      if (!completer.isCompleted) {
        await _stt.stop();
        final words = _stt.lastRecognizedWords;
        completer.complete(words.isEmpty ? null : words);
      }
    });

    return completer.future;
  }

  @override
  Future<void> stopListening() async {
    if (_stt.isListening) await _stt.stop();
  }

  @override
  Future<void> dispose() async {
    await _stt.cancel();
    await _player.dispose();
    await _fallbackTts.stop();
  }
}
