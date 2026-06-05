import 'package:flutter/material.dart';

import '../core/a11y/a11y.dart';
import '../core/theme/tokens.dart';

/// Floating pill-shaped bottom navigation.
///
/// Five slots: Home · Progress · [raised circular gradient START button] ·
/// Profile · Settings. The centre button launches a session from anywhere.
/// Taps only (no gestures); every item is icon + label so colour isn't the
/// only cue, and each target is >= [A11y.minTapTarget].
class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.index,
    required this.onSelect,
    required this.onStart,
  });

  /// 0=Home, 1=Progress, 2=Profile, 3=Settings (the centre Start isn't an index).
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: AppShadows.raised,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: index == 0,
              onTap: () => onSelect(0),
            ),
            _NavItem(
              icon: Icons.insights_rounded,
              label: 'Progress',
              selected: index == 1,
              onTap: () => onSelect(1),
            ),
            _StartButton(onTap: onStart),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              selected: index == 2,
              onTap: () => onSelect(2),
            ),
            _NavItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              selected: index == 3,
              onTap: () => onSelect(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.ink : AppColors.label;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
              minWidth: A11y.minTapTarget, minHeight: A11y.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Start walk',
      child: InkResponse(
        onTap: onTap,
        radius: 44,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            shape: BoxShape.circle,
            boxShadow: AppShadows.raised,
          ),
          child: const Icon(Icons.directions_walk, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}
