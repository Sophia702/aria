/// The rhythmic walking beats offered on the Choose-beat screen and the
/// mid-walk beat switcher. Single source of truth so both stay in sync.
class Beat {
  final String name;
  final String sub;
  final int bpm;
  final String file;
  const Beat(
      {required this.name,
      required this.sub,
      required this.bpm,
      required this.file});
}

const List<Beat> kBeats = [
  Beat(name: 'Gentle Waltz', sub: 'Gentle and graceful', bpm: 77, file: 'assets/sounds/Valse Gymnopedie (77 bpm).wav'),
  Beat(name: 'Easy Flow', sub: 'Easy flowing pace', bpm: 80, file: 'assets/sounds/Infinite Perspective (80 bpm).wav'),
  Beat(name: 'Evening Stroll', sub: 'Calm evening walk', bpm: 101, file: 'assets/sounds/Evening (101 bpm).wav'),
  Beat(name: 'Upbeat Stride', sub: 'Upbeat and energetic', bpm: 116, file: 'assets/sounds/Kawai Kitsune (116 bpm).wav'),
];
