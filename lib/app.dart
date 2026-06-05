import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/main_shell.dart';

/// Root widget. Boots into the main shell (Home · Progress · Start · Profile ·
/// Settings). Onboarding (01–05) will gate this on first run in a later round.
class AriaApp extends StatelessWidget {
  const AriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'aria',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const MainShell(),
    );
  }
}
