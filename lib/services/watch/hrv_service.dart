import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class HeartRateReading {
  final double bpm;
  final DateTime timestamp;
  const HeartRateReading({required this.bpm, required this.timestamp});
}

// Keep alias so apple_watch_screen.dart compiles without changes.
typedef HrvReading = HeartRateReading;

enum HrvAuthState { unknown, authorized, denied }

class HrvService {
  static const _channel = MethodChannel('aria/heartrate');

  static Future<HrvAuthState> requestAuth() async {
    if (!Platform.isIOS) return HrvAuthState.denied;
    try {
      final ok = await _channel.invokeMethod<bool>('requestAuth') ?? false;
      return ok ? HrvAuthState.authorized : HrvAuthState.denied;
    } on MissingPluginException {
      return HrvAuthState.unknown; // channel not ready yet — different from denied
    } catch (_) {
      return HrvAuthState.denied;
    }
  }

  static Future<HeartRateReading?> latestReading() async {
    if (!Platform.isIOS) return null;
    try {
      final bpm = await _channel.invokeMethod<double>('latestBPM');
      if (bpm == null || bpm <= 0) return null;
      return HeartRateReading(bpm: bpm, timestamp: DateTime.now());
    } catch (_) {
      return null;
    }
  }

  // Polls every 5 s. Retries auth indefinitely so granting permission later works.
  static Stream<HeartRateReading?> liveStream() async* {
    if (!Platform.isIOS) {
      yield null;
      return;
    }
    while (true) {
      final auth = await requestAuth();
      if (auth == HrvAuthState.authorized) break;
      // Not yet authorized — keep waiting. Yields null so the UI shows Searching.
      yield null;
      await Future.delayed(const Duration(seconds: 3));
    }
    // Authorized — start polling.
    HeartRateReading? last;
    while (true) {
      try {
        final reading = await latestReading();
        if (reading != null &&
            (last == null || reading.timestamp != last.timestamp)) {
          last = reading;
          yield reading;
        } else if (reading == null && last == null) {
          yield null;
        }
      } catch (_) {
        yield null;
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }
}
