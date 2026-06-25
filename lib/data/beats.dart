import '../services/cue/cue_engine.dart';

/// The rhythmic walking beats offered on the Choose-beat screen and the
/// mid-walk beat switcher. Single source of truth so both stay in sync.
///
/// Two kinds:
///   - [BeatKind.music]: a pre-recorded ambient track ([file]), authored at
///     [bpm]. Played by WalkingScreen's own player; speed-scaled against live
///     cadence.
///   - [BeatKind.click]: a synthesized metronome click ([sound]), played by
///     the session's [CueEngine] — the same engine the Cadence Tracker used,
///     so it inherits its glitch-free, cadence-scaled re-tempo for free.
enum BeatKind { music, click }

class Beat {
  final String name;
  final String sub;
  final int bpm;
  final BeatKind kind;
  final String? file; // BeatKind.music
  final BeatSound? sound; // BeatKind.click
  const Beat({
    required this.name,
    required this.sub,
    required this.bpm,
    this.kind = BeatKind.music,
    this.file,
    this.sound,
  });
}

const List<Beat> kBeats = [
  Beat(name: 'Marimba', sub: 'Warm wooden mallet', bpm: 100, kind: BeatKind.click, sound: BeatSound.marimba),
  Beat(name: 'Gentle Waltz', sub: 'Gentle and graceful', bpm: 77, file: 'assets/sounds/Valse Gymnopedie (77 bpm).wav'),
  Beat(name: 'Easy Flow', sub: 'Easy flowing pace', bpm: 80, file: 'assets/sounds/Infinite Perspective (80 bpm).wav'),
  Beat(name: 'Evening Stroll', sub: 'Calm evening walk', bpm: 101, file: 'assets/sounds/Evening (101 bpm).wav'),
  Beat(name: 'Upbeat Stride', sub: 'Upbeat and energetic', bpm: 116, file: 'assets/sounds/Kawai Kitsune (116 bpm).wav'),
  Beat(name: 'Click', sub: 'Crisp metronome tap', bpm: 100, kind: BeatKind.click, sound: BeatSound.click),
  Beat(name: 'Bell', sub: 'Soft chime', bpm: 100, kind: BeatKind.click, sound: BeatSound.bell),
  Beat(name: 'Woodblock', sub: 'Percussive knock', bpm: 100, kind: BeatKind.click, sound: BeatSound.woodblock),
  Beat(name: 'Chiptune', sub: '8-bit bloop', bpm: 100, kind: BeatKind.click, sound: BeatSound.chiptune),
  Beat(name: 'Cowbell', sub: 'Metallic clang', bpm: 100, kind: BeatKind.click, sound: BeatSound.cowbell),
  Beat(name: 'Shaker', sub: 'Soft noise burst', bpm: 100, kind: BeatKind.click, sound: BeatSound.shaker),
  Beat(name: 'Sonar', sub: 'Descending ping', bpm: 100, kind: BeatKind.click, sound: BeatSound.sonar),
];
