/// Rotating "Today's note" — one encouraging line per calendar day, shown on
/// the Progress page and the post-walk Summary (always the same note on a given
/// day). Cycles through a fixed set so it changes daily.
class DailyNote {
  DailyNote._();

  static const List<String> notes = [
    'Every step you take builds strength. Be proud you showed up today.',
    'Let the beat guide you — one steady step at a time.',
    'Small, steady steps add up to big change.',
    'Your pace is the right pace. Move with confidence.',
    'Consistency beats intensity. Showing up is the win.',
    'Breathe, relax your shoulders, and find your rhythm.',
  ];

  /// Stable for the whole calendar day, rotating through [notes].
  static String forToday([DateTime? now]) {
    final d = now ?? DateTime.now();
    final dayOfYear = d.difference(DateTime(d.year)).inDays;
    return notes[dayOfYear % notes.length];
  }
}
