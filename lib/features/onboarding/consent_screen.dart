import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/persistence/app_prefs.dart';
import '../../widgets/aria_logo.dart';
import '../../widgets/gradient_button.dart';

class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, required this.next});

  /// The screen to navigate to after the user accepts.
  final Widget next;

  Future<void> _accept(BuildContext context) async {
    await AppPrefs.setConsented();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppTheme.pageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const AriaLogo(size: 32, showWordmark: false),
                    const SizedBox(width: 8),
                    Text('aria',
                        style: AppType.displaySerif.copyWith(fontSize: 26)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Before you begin', style: AppType.h1),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Please read this short notice so you know how aria works '
                  'and how to use it safely.',
                  style: AppType.body,
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _ConsentCard(
                          icon: Icons.sensors_rounded,
                          iconBg: const Color(0xFFE8F5E9),
                          iconColor: AppColors.primary,
                          title: 'Data we collect',
                          body:
                              'aria reads motion and gait data from wearable sensors '
                              '(accelerometer and gyroscope) to detect your walking '
                              'cadence and movement patterns.\n\n'
                              'All data is processed on this device only. Nothing is '
                              'uploaded, shared, or stored in the cloud.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ConsentCard(
                          icon: Icons.auto_awesome_rounded,
                          iconBg: const Color(0xFFFFF3E0),
                          iconColor: const Color(0xFFE65100),
                          title: 'AI limitations',
                          body:
                              'aria uses machine learning to assist with cadence '
                              'tracking and freeze-of-gait detection. It is not a '
                              'medical device and its predictions are not always '
                              'accurate.\n\n'
                              'Do not rely on aria as your sole source of safety or '
                              'medical guidance.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ConsentCard(
                          icon: Icons.health_and_safety_rounded,
                          iconBg: const Color(0xFFFFEBEE),
                          iconColor: const Color(0xFFC62828),
                          title: 'Your safety',
                          body:
                              'You are responsible for your own safety at all times. '
                              'Always remain aware of your surroundings while using '
                              'aria.\n\n'
                              'Walk in safe environments, avoid hazards, and stop '
                              'using the app if you feel unwell. If you are unsure '
                              'whether aria is right for you, speak with your '
                              'clinician first.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                GradientButton(
                  label: 'I understand — continue',
                  icon: Icons.check_rounded,
                  onPressed: () => _accept(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Text(
                    'By continuing you acknowledge that you have read '
                    'and understood the above.',
                    style: AppType.label.copyWith(
                        color: AppColors.inkFaint, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppTheme.cardDecoration(radius: AppRadii.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.h2.copyWith(fontSize: 16)),
                const SizedBox(height: 6),
                Text(body,
                    style:
                        AppType.body.copyWith(fontSize: 14, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
