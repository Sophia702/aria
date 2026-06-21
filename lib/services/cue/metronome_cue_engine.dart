import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'cue_engine.dart';

/// MVP cue: a continuous metronome.
///
/// Synthesises one beat as a 16-bit PCM WAV at a reference tempo and loops it
/// gaplessly (LoopMode.one). Small tempo changes are applied as a playback
/// *speed* multiplier (just_audio's setSpeed) — a continuous adjustment with
/// no stop/restart, so re-tempoing doesn't produce an audible jump. Only a
/// large drift from the reference tempo (where speeding up would noticeably
/// shift pitch) or an explicit sound change regenerates the buffer.
class MetronomeCueEngine implements CueEngine {
  MetronomeCueEngine();

  final AudioPlayer _player = AudioPlayer();
  static const int _sampleRate = 22050;

  // Speed multiplier stays in this range before we reload at a new reference
  // tempo instead — beyond it pitch shift becomes noticeable.
  static const double _maxSpeedDrift = 1.4;
  static const double _minSpeedDrift = 0.7;

  double _bpm = 100; // displayed / logical tempo
  double _referenceBpm = 100; // tempo the loaded buffer was encoded at
  double _volume = 0.9;
  bool _playing = false;
  int _fileSeq = 0;
  BeatSound _sound = BeatSound.bell;

  @override
  bool get isPlaying => _playing;

  @override
  double get bpm => _bpm;

  BeatSound get sound => _sound;

  @override
  Future<void> init() async {
    await _player.setLoopMode(LoopMode.one);
    await _player.setVolume(_volume);
  }

  @override
  Future<void> startCue({required double bpm}) async {
    _bpm = bpm.clamp(30, 240);
    _referenceBpm = _bpm;
    await _loadBeat();
    await _player.setSpeed(1.0);
    await _player.setVolume(_volume);
    unawaited(_player.play());
    _playing = true;
  }

  @override
  Future<void> setTempo(double bpm) async {
    _bpm = bpm.clamp(30, 240);
    if (!_playing) return;

    final ratio = _bpm / _referenceBpm;
    if (ratio > _maxSpeedDrift || ratio < _minSpeedDrift) {
      // Drifted too far for a clean speed change — reload at a new
      // reference tempo (the rare, audible-jump path).
      _referenceBpm = _bpm;
      await _loadBeat();
      await _player.setSpeed(1.0);
      unawaited(_player.play());
    } else {
      // Continuous, glitch-free re-tempo: same buffer, new playback rate.
      await _player.setSpeed(ratio);
    }
  }

  @override
  Future<void> setSound(BeatSound sound) async {
    _sound = sound;
    _referenceBpm = _bpm;
    if (_playing) {
      await _loadBeat();
      await _player.setSpeed(1.0);
      unawaited(_player.play());
    }
  }

  @override
  Future<void> setVolume(double volume01) async {
    _volume = volume01.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  @override
  Future<void> stopCue() async {
    _playing = false;
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    _playing = false;
    await _player.dispose();
  }

  Future<void> _loadBeat() async {
    final bytes = _encodeBeatWav(_referenceBpm, _sampleRate, _sound);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/aria_click_${_fileSeq++}.wav');
    await file.writeAsBytes(bytes, flush: true);
    await _player.setFilePath(file.path);
    await _player.setLoopMode(LoopMode.one);
  }

  static Uint8List _encodeBeatWav(double bpm, int sampleRate, BeatSound sound) {
    final beatSamples = (sampleRate * 60.0 / bpm).round();
    final pcm = Int16List(beatSamples);

    switch (sound) {
      case BeatSound.click:
        _synthClick(pcm, sampleRate);
      case BeatSound.bell:
        _synthBell(pcm, sampleRate);
      case BeatSound.woodblock:
        _synthWoodblock(pcm, sampleRate);
      case BeatSound.chiptune:
        _synthChiptune(pcm, sampleRate);
      case BeatSound.marimba:
        _synthMarimba(pcm, sampleRate);
      case BeatSound.cowbell:
        _synthCowbell(pcm, sampleRate);
      case BeatSound.shaker:
        _synthShaker(pcm, sampleRate);
      case BeatSound.sonar:
        _synthSonar(pcm, sampleRate);
    }

    return _wrapWav(pcm, sampleRate);
  }

  // ── Sound synthesis ────────────────────────────────────────────────────────

  static void _synthClick(Int16List pcm, int sampleRate) {
    const clickMs = 35;
    const freq = 1400.0;
    final n = (sampleRate * clickMs / 1000).round().clamp(0, pcm.length);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final s = sin(2 * pi * freq * t) * exp(-t * 45);
      pcm[i] = (s * 28000).round().clamp(-32768, 32767);
    }
  }

  static void _synthBell(Int16List pcm, int sampleRate) {
    const clickMs = 160;
    const freq1 = 523.0;  // C5 fundamental
    const freq2 = 1046.0; // C6 harmonic
    final n = (sampleRate * clickMs / 1000).round().clamp(0, pcm.length);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final s = sin(2 * pi * freq1 * t) * exp(-t * 12) * 0.65
              + sin(2 * pi * freq2 * t) * exp(-t * 32) * 0.35;
      pcm[i] = (s * 27000).round().clamp(-32768, 32767);
    }
  }

  static void _synthWoodblock(Int16List pcm, int sampleRate) {
    const clickMs = 60;
    const freq = 320.0;
    final n = (sampleRate * clickMs / 1000).round().clamp(0, pcm.length);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      // Pitched body + a touch of noise for the wood texture
      final body = sin(2 * pi * freq * t) * exp(-t * 55);
      final noise = (Random().nextDouble() * 2 - 1) * exp(-t * 120) * 0.25;
      pcm[i] = ((body + noise) * 28000).round().clamp(-32768, 32767);
    }
  }

  static void _synthChiptune(Int16List pcm, int sampleRate) {
    // Square-wave approximation (odd harmonics) at A5 (880 Hz).
    // Sums 6 harmonics: gives that classic 8-bit bloop.
    const clickMs = 80;
    const freq = 880.0;
    final n = (sampleRate * clickMs / 1000).round().clamp(0, pcm.length);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final env = exp(-t * 22);
      double s = 0;
      for (var h = 0; h < 6; h++) {
        final harmonic = 2 * h + 1;
        s += sin(2 * pi * freq * harmonic * t) / harmonic;
      }
      s *= (4 / pi); // normalise square-wave amplitude
      pcm[i] = (s * env * 16000).round().clamp(-32768, 32767);
    }
  }

  static void _synthMarimba(Int16List pcm, int sampleRate) {
    const clickMs = 140;
    const freq = 196.0; // wooden mallet fundamental
    final n = (sampleRate * clickMs / 1000).round().clamp(0, pcm.length);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      // Fundamental + a slightly inharmonic overtone, like a wooden bar.
      final s = sin(2 * pi * freq * t) * exp(-t * 18) * 0.7 +
          sin(2 * pi * freq * 3.96 * t) * exp(-t * 38) * 0.3;
      pcm[i] = (s * 27000).round().clamp(-32768, 32767);
    }
  }

  static void _synthCowbell(Int16List pcm, int sampleRate) {
    const clickMs = 110;
    const freq1 = 587.0; // D5
    const freq2 = 845.0; // deliberately non-harmonic -> metallic clang
    final n = (sampleRate * clickMs / 1000).round().clamp(0, pcm.length);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final s1 = sin(2 * pi * freq1 * t).sign;
      final s2 = sin(2 * pi * freq2 * t).sign;
      final s = (s1 * 0.5 + s2 * 0.5) * exp(-t * 16);
      pcm[i] = (s * 22000).round().clamp(-32768, 32767);
    }
  }

  static void _synthShaker(Int16List pcm, int sampleRate) {
    const clickMs = 45;
    final n = (sampleRate * clickMs / 1000).round().clamp(0, pcm.length);
    final rng = Random();
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final noise = rng.nextDouble() * 2 - 1;
      final s = noise * exp(-t * 90);
      pcm[i] = (s * 24000).round().clamp(-32768, 32767);
    }
  }

  static void _synthSonar(Int16List pcm, int sampleRate) {
    const clickMs = 220;
    const freqStart = 1200.0;
    const freqEnd = 700.0;
    final n = (sampleRate * clickMs / 1000).round().clamp(0, pcm.length);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final frac = t / (clickMs / 1000);
      final freq = freqStart + (freqEnd - freqStart) * frac;
      phase += 2 * pi * freq / sampleRate;
      final s = sin(phase) * exp(-t * 8);
      pcm[i] = (s * 26000).round().clamp(-32768, 32767);
    }
  }

  // ── WAV wrapper ───────────────────────────────────────────────────────────

  static Uint8List _wrapWav(Int16List samples, int sampleRate) {
    final data =
        samples.buffer.asUint8List(samples.offsetInBytes, samples.lengthInBytes);
    final out = BytesBuilder();
    void str(String s) => out.add(s.codeUnits);
    void u32(int v) =>
        out.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
    void u16(int v) =>
        out.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

    str('RIFF');
    u32(36 + data.length);
    str('WAVE');
    str('fmt ');
    u32(16);
    u16(1); // PCM
    u16(1); // mono
    u32(sampleRate);
    u32(sampleRate * 2);
    u16(2);
    u16(16);
    str('data');
    u32(data.length);
    out.add(data);
    return out.toBytes();
  }
}
