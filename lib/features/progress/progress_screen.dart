import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/stat_card.dart';

/// Screen 07 — Progress. Motivational quote, headline stats, this-week chart,
/// weekly summary, and recent sessions. Values are mock until session history
/// persistence lands (a later round).
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  // Minutes walked per day this week (mock).
  static const _week = [12, 0, 18, 8, 22, 15, 10];
  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
          AppSpacing.lg, AppSpacing.navClearance),
      children: [
        Text('Progress', style: AppType.h1),
        const SizedBox(height: AppSpacing.md),
        const _QuoteCard(
          quote: 'Every step you take is a small act of courage.',
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: const [
            Expanded(
              child: StatCard(
                icon: Icons.directions_walk,
                value: '12',
                caption: 'Total sessions',
                accent: AppColors.primary,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                icon: Icons.local_fire_department,
                value: '5',
                caption: 'This week',
                accent: AppColors.rose,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ChartCard(week: _week, days: _days),
        const SizedBox(height: AppSpacing.md),
        const _WeeklySummary(),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent sessions', style: AppType.h2),
            Text('See all', style: AppType.label.copyWith(color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const _SessionTile(date: 'Today · 9:12', steps: 642, mins: 6),
        const _SessionTile(date: 'Yesterday · 5:40', steps: 1180, mins: 11),
        const _SessionTile(date: 'Mon · 8:30', steps: 980, mins: 9),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});
  final String quote;

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
        children: [
          const Icon(Icons.format_quote_rounded, color: Colors.white, size: 30),
          const SizedBox(height: AppSpacing.sm),
          Text(
            quote,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.week, required this.days});
  final List<int> week;
  final List<String> days;

  @override
  Widget build(BuildContext context) {
    final maxY = (week.reduce((a, b) => a > b ? a : b) + 6).toDouble();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This week', style: AppType.label),
          const SizedBox(height: 2),
          Text('Minutes walked', style: AppType.h2.copyWith(fontSize: 19)),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(days[value.toInt() % days.length],
                            style: AppType.label.copyWith(fontSize: 12)),
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < week.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: week[i].toDouble(),
                        width: 16,
                        color: i == week.length - 2
                            ? AppColors.primary
                            : AppColors.surfaceDeep,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySummary extends StatelessWidget {
  const _WeeklySummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: const [
          _SummaryRow(label: 'Avg cadence', value: '108 steps/min'),
          Divider(height: AppSpacing.lg, color: AppColors.surfaceDeep),
          _SummaryRow(label: 'Total walking time', value: '1h 25m'),
          Divider(height: AppSpacing.lg, color: AppColors.surfaceDeep),
          _SummaryRow(label: 'Walks this week', value: '5'),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppType.body.copyWith(fontSize: 16)),
        Text(value, style: AppType.h2.copyWith(fontSize: 18)),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.date, required this.steps, required this.mins});
  final String date;
  final int steps;
  final int mins;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppTheme.cardDecoration(radius: AppRadii.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_walk, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: AppType.h2.copyWith(fontSize: 16)),
                Text('$steps steps · ${mins}m', style: AppType.label),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.label),
        ],
      ),
    );
  }
}
