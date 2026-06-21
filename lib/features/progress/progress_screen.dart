import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/daily_note.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/walk_session.dart';
import '../../data/models/walk_stats.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../widgets/stat_card.dart';
import 'all_sessions_screen.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stats = ref.watch(walkStatsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
          AppSpacing.lg, AppSpacing.navClearance),
      children: [
        Text(l10n?.progress ?? 'Progress', style: AppType.h1),
        const SizedBox(height: AppSpacing.md),
        _QuoteCard(quote: DailyNote.forToday()),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.directions_walk,
                value: '${stats.totalSessions}',
                caption: l10n?.totalSessions ?? 'Total sessions',
                accent: AppColors.primary,
                showStrip: false,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                icon: Icons.local_fire_department,
                value: '${stats.walksThisWeek}',
                caption: l10n?.thisWeek ?? 'This week',
                accent: AppColors.primary,
                showStrip: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ChartAndSummaryCard(
          week: stats.weekMinutes,
          days: _days,
          cadence: stats.weekCadence,
          steps: stats.weekSteps,
          avgCadence: stats.avgCadence,
          totalTimeLabel: WalkStats.formatDuration(stats.totalWalkTime),
          walksThisWeek: stats.walksThisWeek,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n?.recentSessions ?? 'Recent sessions', style: AppType.h2),
            if (stats.recent.isNotEmpty)
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AllSessionsScreen())),
                child: Text(l10n?.seeAll ?? 'See all',
                    style: AppType.label.copyWith(color: AppColors.primary)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (stats.recent.isEmpty)
          const _EmptyRecent()
        else
          for (final s in stats.recent) _SessionTile(session: s),
      ],
    );
  }
}

/// Friendly empty state before any walk has been recorded.
class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: AppTheme.cardDecoration(radius: 18),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.directions_walk_rounded,
              color: AppColors.inkFaint, size: 30),
          const SizedBox(height: AppSpacing.sm),
          Text('No walks yet',
              style: AppType.h2.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text('Your sessions will appear here once you start walking.',
              style: AppType.label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});
  final String quote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.pinkGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -12,
            right: 4,
            child: Icon(
              Icons.format_quote_rounded,
              color: Colors.white.withValues(alpha: 0.10),
              size: 88,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.todaysNote ?? "Today's note",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: kFontFamily,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                quote,
                style: AppType.displaySerif.copyWith(
                  fontSize: 20,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartAndSummaryCard extends StatefulWidget {
  const _ChartAndSummaryCard({
    required this.week,
    required this.days,
    required this.cadence,
    required this.steps,
    required this.avgCadence,
    required this.totalTimeLabel,
    required this.walksThisWeek,
  });
  final List<int> week;
  final List<String> days;
  final List<int> cadence;
  final List<int> steps;
  final double avgCadence;
  final String totalTimeLabel;
  final int walksThisWeek;

  @override
  State<_ChartAndSummaryCard> createState() => _ChartAndSummaryCardState();
}

class _ChartAndSummaryCardState extends State<_ChartAndSummaryCard> {
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final weekMax = widget.week.isEmpty
        ? 0
        : widget.week.reduce((a, b) => a > b ? a : b);
    final maxY = (weekMax + 6).toDouble();

    final String cadenceVal;
    final String durationVal;
    final String stepsVal;
    final String cadenceLabel;
    final String durationLabel;
    final String stepsLabel;

    if (_selectedDay == null) {
      cadenceLabel = l10n?.avgCadence ?? 'Avg cadence';
      durationLabel = l10n?.totalWalkTime ?? 'Total walking time';
      stepsLabel = l10n?.walksThisWeek ?? 'Walks this week';
      cadenceVal = widget.avgCadence > 0
          ? '${widget.avgCadence.round()} steps/min'
          : '--';
      durationVal = widget.totalTimeLabel;
      stepsVal = '${widget.walksThisWeek}';
    } else if (widget.week[_selectedDay!] > 0) {
      cadenceLabel = l10n?.avgCadence ?? 'Cadence';
      durationLabel = l10n?.duration ?? 'Duration';
      stepsLabel = l10n?.steps ?? 'Steps';
      cadenceVal = '${widget.cadence[_selectedDay!]} steps/min';
      durationVal = '${widget.week[_selectedDay!]} min';
      stepsVal = '${widget.steps[_selectedDay!]}';
    } else {
      cadenceLabel = l10n?.avgCadence ?? 'Cadence';
      durationLabel = l10n?.duration ?? 'Duration';
      stepsLabel = l10n?.steps ?? 'Steps';
      cadenceVal = '--';
      durationVal = '--';
      stepsVal = '--';
    }

    return Container(
      decoration: AppTheme.cardDecoration(radius: 18),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n?.thisWeek ?? 'This week',
                            style: AppType.label),
                        const SizedBox(height: 2),
                        Text(l10n?.minutesWalked ?? 'Minutes walked',
                            style: AppType.h2.copyWith(fontSize: 19)),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchCallback:
                            (FlTouchEvent event, BarTouchResponse? response) {
                          if (!event.isInterestedForInteractions) return;
                          final idx =
                              response?.spot?.touchedBarGroupIndex;
                          if (idx == null) return;
                          setState(() {
                            _selectedDay =
                                _selectedDay == idx ? null : idx;
                          });
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.transparent,
                          tooltipPadding: EdgeInsets.zero,
                          getTooltipItem: (a, b, c, d) => null,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                widget.days[
                                    value.toInt() % widget.days.length],
                                style: AppType.label.copyWith(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < widget.week.length; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: widget.week[i].toDouble(),
                              width: 18,
                              gradient: i == _selectedDay
                                  ? const LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        AppColors.primary,
                                        AppColors.fab
                                      ],
                                    )
                                  : null,
                              color: i == _selectedDay
                                  ? null
                                  : AppColors.surfaceDeep,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                _SummaryRow(label: cadenceLabel, value: cadenceVal),
                const Divider(
                    height: AppSpacing.lg,
                    thickness: 1,
                    color: AppColors.lineSoft),
                _SummaryRow(label: durationLabel, value: durationVal),
                const Divider(
                    height: AppSpacing.lg,
                    thickness: 1,
                    color: AppColors.lineSoft),
                _SummaryRow(label: stepsLabel, value: stepsVal),
              ],
            ),
          ),
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
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.fab,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(label, style: AppType.body.copyWith(fontSize: 16)),
        const Spacer(),
        Text(value, style: AppType.h2.copyWith(fontSize: 18)),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final WalkSession session;

  /// "Today · 9:12", "Yesterday · 5:40", "Mon · 8:30".
  static String label(WalkSession s) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = s.startedAt;
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    final time = DateFormat('h:mm').format(d);
    if (diff == 0) return 'Today · $time';
    if (diff == 1) return 'Yesterday · $time';
    if (diff < 7) return '${DateFormat('EEE').format(d)} · $time';
    return '${DateFormat('MMM d').format(d)} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final mins = session.duration.inMinutes;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: AppTheme.cardDecoration(radius: 18),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_walk,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label(session), style: AppType.h2.copyWith(fontSize: 16)),
                  Text('${session.steps} steps · ${mins}m',
                      style: AppType.label),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}
