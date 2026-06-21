import 'walk_session.dart';

/// Derived, display-ready aggregates computed from the stored [WalkSession]s.
/// Everything Home and Progress show comes from here — no fake numbers.
class WalkStats {
  final int totalSessions;
  final int walksThisWeek;
  final int currentStreak; // consecutive days ending today/yesterday
  final Duration totalWalkTime;
  final double avgCadence; // mean steps/min across sessions

  /// Mon..Sun buckets for the current week.
  final List<int> weekMinutes;
  final List<int> weekCadence;
  final List<int> weekSteps;

  final WalkSession? last;
  final List<WalkSession> recent; // up to 3 newest

  const WalkStats({
    required this.totalSessions,
    required this.walksThisWeek,
    required this.currentStreak,
    required this.totalWalkTime,
    required this.avgCadence,
    required this.weekMinutes,
    required this.weekCadence,
    required this.weekSteps,
    required this.last,
    required this.recent,
  });

  bool get isEmpty => totalSessions == 0;

  factory WalkStats.from(List<WalkSession> sessions, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    // Monday as the first day of the week.
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final weekMinutes = List<int>.filled(7, 0);
    final weekStepsSum = List<int>.filled(7, 0);
    final weekCadenceSum = List<double>.filled(7, 0);
    final weekCount = List<int>.filled(7, 0);

    var totalSeconds = 0;
    var cadenceSum = 0.0;
    var cadenceCount = 0;
    var walksThisWeek = 0;

    for (final s in sessions) {
      totalSeconds += s.durationSeconds;
      if (s.avgCadence > 0) {
        cadenceSum += s.avgCadence;
        cadenceCount++;
      }
      final d = s.startedAt;
      final day = DateTime(d.year, d.month, d.day);
      if (!day.isBefore(weekStart) &&
          day.isBefore(weekStart.add(const Duration(days: 7)))) {
        walksThisWeek++;
        final idx = day.difference(weekStart).inDays;
        if (idx >= 0 && idx < 7) {
          weekMinutes[idx] += (s.durationSeconds / 60).round();
          weekStepsSum[idx] += s.steps;
          weekCadenceSum[idx] += s.avgCadence;
          weekCount[idx]++;
        }
      }
    }

    final weekCadence = [
      for (var i = 0; i < 7; i++)
        weekCount[i] == 0 ? 0 : (weekCadenceSum[i] / weekCount[i]).round(),
    ];

    // Streak: distinct walk days, counting back from today (or yesterday).
    final walkDays = sessions
        .map((s) => DateTime(
            s.startedAt.year, s.startedAt.month, s.startedAt.day))
        .toSet();
    var streak = 0;
    var cursor = today;
    if (!walkDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (walkDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return WalkStats(
      totalSessions: sessions.length,
      walksThisWeek: walksThisWeek,
      currentStreak: streak,
      totalWalkTime: Duration(seconds: totalSeconds),
      avgCadence: cadenceCount == 0 ? 0 : cadenceSum / cadenceCount,
      weekMinutes: weekMinutes,
      weekCadence: weekCadence,
      weekSteps: weekStepsSum,
      last: sessions.isEmpty ? null : sessions.first,
      recent: sessions.take(3).toList(),
    );
  }

  /// "1h 25m" / "25m" / "0m"
  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
