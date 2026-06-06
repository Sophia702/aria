import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// A white card with a small icon chip, a big bold value, and a caption.
/// Used across Progress and Summary.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.caption,
    this.accent = AppColors.primary,
  });

  final IconData icon;
  final String value;
  final String caption;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(value,
              style: AppType.h1.copyWith(fontSize: 28, letterSpacing: -1)),
          const SizedBox(height: 2),
          Text(caption, style: AppType.label),
        ],
      ),
    );
  }
}
