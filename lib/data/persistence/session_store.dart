import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/walk_session.dart';

/// Local persistence for completed walking sessions (JSON in SharedPreferences).
/// This is the single source of truth behind Home, Progress and Summary stats.
class SessionStore {
  SessionStore._();
  static const _key = 'walk_sessions_v1';

  /// All stored sessions, newest first.
  static Future<List<WalkSession>> all() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => WalkSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      list.sort((a, b) => b.startedAtMs.compareTo(a.startedAtMs));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(WalkSession s) async {
    final p = await SharedPreferences.getInstance();
    final existing = await all();
    existing.add(s);
    await p.setString(
        _key, jsonEncode(existing.map((e) => e.toJson()).toList()));
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
