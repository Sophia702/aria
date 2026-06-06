import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../providers/providers.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/stat_card.dart';

/// Screen 14 — post-walk Summary. Checkmark, encouragement, the walk's stats,
/// a daily quote, and a mascot placeholder. Done returns Home.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key, this.name = 'Margaret'});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionControllerProvider);
    final minutes = s.elapsed.inSeconds / 60.0;
    final steps = (s.stepsPerMin * minutes).round();
    final mins = s.elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = s.elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      body: AppTheme.pageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: const BoxDecoration(
                    gradient: AppColors.accentGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.raised,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 48),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(child: Text('Nice walk, $name', style: AppType.h1)),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: Text('You kept your rhythm for $mins:$secs.',
                    style: AppType.body),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.directions_walk,
                      value: '$steps',
                      caption: 'Steps',
                      accent: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatCard(
                      icon: Icons.speed,
                      value: '${s.stepsPerMin.round()}',
                      caption: 'Avg pace',
                      accent: AppColors.sage,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatCard(
                      icon: Icons.favorite_rounded,
                      value: '${s.freezesEased}',
                      caption: 'Assists',
                      accent: AppColors.plum,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _QuoteCard(),
              const SizedBox(height: AppSpacing.md),
              _MascotPlaceholder(),
              const SizedBox(height: AppSpacing.lg),
              GradientButton(
                label: 'Done',
                icon: Icons.home_rounded,
                onPressed: () {
                  ref.read(sessionControllerProvider.notifier).reset();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.plumGradient,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Daily thought',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text(
            'Rhythm is a gentle anchor — you found yours today.',
            style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w600,
                height: 1.3),
          ),
        ],
      ),
    );
  }
}

/// Mascot is parked for now — just a labelled placeholder slot (per spec).
class _MascotPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.surfaceDeep),
      ),
      child: Center(
        child: Text('aria mascot — coming soon',
            style: AppType.label.copyWith(color: AppColors.label)),
      ),
    );
  }
}
