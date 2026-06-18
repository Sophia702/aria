import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class WatchCadenceService {
  static const _channel = MethodChannel('aria/cadence');

  static Future<bool> requestAuth() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('requestAuth') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<double?> latestSPM() async {
    if (!Platform.isIOS) return null;
    try {
      return await _channel.invokeMethod<double>('latestSPM');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> startMonitor() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('startMonitor') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopMonitor() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<bool>('stopMonitor');
    } catch (_) {}
  }

  /// Polls every 2 s. Authorises, starts the monitor, then streams SPM values.
  static Stream<double?> liveStream() async* {
    if (!Platform.isIOS) { yield null; return; }

    // Auth loop — keep retrying until granted.
    while (true) {
      final ok = await requestAuth();
      if (ok) break;
      yield null;
      await Future.delayed(const Duration(seconds: 3));
    }

    await startMonitor();

    while (true) {
      final spm = await latestSPM();
      yield spm;
      await Future.delayed(const Duration(seconds: 2));
    }
  }
}
