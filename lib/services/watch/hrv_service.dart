import 'dart:async';
import 'dart:io';

import 'package:health/health.dart';

class HrvReading {
  final double value;
  final DateTime timestamp;
  const HrvReading({required this.value, required this.timestamp});
}

enum HrvAuthState { unknown, authorized, denied }

class HrvService {
  static final Health _health = Health();

  static const _types = [HealthDataType.HEART_RATE_VARIABILITY_SDNN];

  static Future<HrvAuthState> requestAuth() async {
    if (!Platform.isIOS) return HrvAuthState.denied;
    try {
      final ok = await _health.requestAuthorization(_types);
      return ok ? HrvAuthState.authorized : HrvAuthState.denied;
    } catch (_) {
      return HrvAuthState.denied;
    }
  }

  static Future<HrvReading?> latestReading() async {
    if (!Platform.isIOS) return null;
    try {
      final now = DateTime.now();
      final samples = await _health.getHealthDataFromTypes(
        startTime: now.subtract(const Duration(hours: 24)),
        endTime: now,
        types: _types,
      );
      if (samples.isEmpty) return null;
      final latest = samples.last;
      final raw = latest.value;
      final ms = raw is NumericHealthValue ? raw.numericValue.toDouble() : null;
      if (ms == null) return null;
      return HrvReading(value: ms, timestamp: latest.dateFrom);
    } catch (_) {
      return null;
    }
  }

  // Polls every 10 s and yields new readings when they differ from the last.
  static Stream<HrvReading?> liveStream() async* {
    if (!Platform.isIOS) {
      yield null;
      return;
    }

    final auth = await requestAuth();
    if (auth != HrvAuthState.authorized) {
      yield null;
      return;
    }

    HrvReading? last;
    while (true) {
      final reading = await latestReading();
      if (reading != null &&
          (last == null || reading.timestamp != last.timestamp)) {
        last = reading;
        yield reading;
      } else if (reading == null && last == null) {
        yield null;
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  }
}
