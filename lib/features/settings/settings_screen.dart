import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/a11y/a11y.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Screen 10 — Settings. Audio preferences, sensor configuration, notifications.
///
/// Volume/tempo use +/- STEPPERS rather than sliders: a slider needs a drag,
/// which the accessibility rules forbid for tremor users (no fine-motor
/// gestures). Steppers are large, discrete, tap-only targets. (Local state for
/// now; wired to the cue engine + persistence in a later round.)
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _volume = 80; // percent
  int _tempo = 108; // bpm
  bool _reminders = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
          AppSpacing.lg, AppSpacing.navClearance),
      children: [
        Text('Settings', style: AppType.h1),
        const SizedBox(height: AppSpacing.md),
        _Section(title: 'Audio preferences', children: [
          _StepperRow(
            label: 'Cue volume',
            value: '$_volume%',
            onMinus: _volume > 0 ? () => setState(() => _volume -= 10) : null,
            onPlus: _volume < 100 ? () => setState(() => _volume += 10) : null,
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.surfaceDeep),
          _StepperRow(
            label: 'Beat tempo',
            value: '$_tempo bpm',
            onMinus: _tempo > 60 ? () => setState(() => _tempo -= 2) : null,
            onPlus: _tempo < 140 ? () => setState(() => _tempo += 2) : null,
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _Section(title: 'Sensor configuration', children: [
          _RowTile(
            icon: Icons.sensors,
            title: 'Manage sensors',
            trailing: Text('3 connected',
                style: AppType.label.copyWith(color: AppColors.connected)),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sensor management — coming soon')),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _Section(title: 'Notifications', children: [
          _RowTile(
            icon: Icons.notifications_rounded,
            title: 'Daily reminders',
            trailing: Switch(
              value: _reminders,
              activeThumbColor: AppColors.clay,
              onChanged: (v) => setState(() => _reminders = v),
            ),
            onTap: () => setState(() => _reminders = !_reminders),
          ),
        ]),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.label),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppType.h2.copyWith(fontSize: 18)),
              Text(value, style: AppType.label),
            ],
          ),
        ),
        _RoundBtn(icon: Icons.remove, onTap: onMinus),
        const SizedBox(width: AppSpacing.sm),
        _RoundBtn(icon: Icons.add, onTap: onPlus),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Container(
            width: A11y.minTapTarget,
            height: A11y.minTapTarget,
            decoration: BoxDecoration(
              color: enabled ? AppColors.surface : AppColors.surface.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: enabled ? AppColors.ink : AppColors.label, size: 24),
          ),
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: A11y.minTapTarget),
        child: Row(
          children: [
            Icon(icon, color: AppColors.clay, size: 24),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(title, style: AppType.h2.copyWith(fontSize: 18))),
            trailing,
          ],
        ),
      ),
    );
  }
}
