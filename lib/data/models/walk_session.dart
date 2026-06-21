/// One completed walking session, persisted locally and shown on Home,
/// Progress and the post-walk Summary.
class WalkSession {
  final int startedAtMs; // epoch ms — also the stable id
  final int durationSeconds;
  final int steps;
  final double avgCadence; // steps per minute
  final int freezesEased;

  const WalkSession({
    required this.startedAtMs,
    required this.durationSeconds,
    required this.steps,
    required this.avgCadence,
    required this.freezesEased,
  });

  DateTime get startedAt => DateTime.fromMillisecondsSinceEpoch(startedAtMs);
  Duration get duration => Duration(seconds: durationSeconds);

  Map<String, dynamic> toJson() => {
        's': startedAtMs,
        'd': durationSeconds,
        'n': steps,
        'c': avgCadence,
        'f': freezesEased,
      };

  factory WalkSession.fromJson(Map<String, dynamic> j) => WalkSession(
        startedAtMs: j['s'] as int,
        durationSeconds: j['d'] as int,
        steps: j['n'] as int,
        avgCadence: (j['c'] as num).toDouble(),
        freezesEased: (j['f'] as int?) ?? 0,
      );
}
