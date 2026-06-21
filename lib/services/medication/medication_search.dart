import 'dart:convert';

import 'package:http/http.dart' as http;

/// Medication name autocomplete backed by the U.S. National Library of
/// Medicine's RxTerms API (part of RxNorm/RxNav). Free, no API key, CORS-enabled,
/// covers the large majority of US & Canadian prescription drugs.
class MedicationSearch {
  static const _base =
      'https://clinicaltables.nlm.nih.gov/api/rxterms/v3/search';

  /// Returns up to ~12 display names matching [query] (min 2 chars).
  static Future<List<String>> suggest(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final uri = Uri.parse(
          '$_base?terms=${Uri.encodeQueryComponent(q)}&maxList=12');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const [];
      // Format: [total, [codes], {extras}|null, [[display], ...]]
      final data = jsonDecode(res.body) as List;
      if (data.length < 4 || data[3] is! List) return const [];
      return (data[3] as List)
          .map((e) =>
              (e is List && e.isNotEmpty) ? e.first.toString() : e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Medications are persisted as a JSON list of strings under the `meds` key.
  static List<String> decode(String raw) {
    if (raw.isEmpty) return [];
    try {
      final v = jsonDecode(raw);
      if (v is List) return v.map((e) => e.toString()).toList();
    } catch (_) {
      // Legacy: a plain comma/﻿newline string from the old free-text field.
      return raw
          .split(RegExp(r'[,\n]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  static String encode(List<String> meds) => jsonEncode(meds);
}
