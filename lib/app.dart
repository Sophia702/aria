import 'package:flutter/material.dart';

import 'core/no_stretch_scroll.dart';
import 'core/theme/app_theme.dart';
import 'data/persistence/app_prefs.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/shell/main_shell.dart';
import 'providers/providers.dart';
import 'widgets/aria_logo.dart';
import 'widgets/voice_overlay.dart';

/// Root widget. Shows onboarding on first run, otherwise the main shell.
class AriaApp extends StatelessWidget {
  const AriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'aria',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const NoStretchScrollBehavior(),
      navigatorKey: navigatorKey,
      builder: (context, child) => VoiceOverlay(child: child ?? const SizedBox()),
      home: const _Boot(),
    );
  }
}

class _Boot extends StatelessWidget {
  const _Boot();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AppPrefs.isOnboarded(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            body: AppTheme.pageBackground(
              child: const Center(child: AriaLogo(size: 56)),
            ),
          );
        }
        return snap.data! ? const MainShell() : const OnboardingFlow();
      },
    );
  }
}
