import 'dart:async';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../services/watch/hrv_service.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _hrvStreamProvider = StreamProvider.autoDispose<HrvReading?>((ref) {
  // Wraps in try-catch at provider level so any platform exception → null.
  Stream<HrvReading?> safe() async* {
    try {
      yield* HrvService.liveStream();
    } catch (_) {
      yield null;
    }
  }
  return safe();
});

// ── Screen ───────────────────────────────────────────────────────────────────

class AppleWatchScreen extends ConsumerStatefulWidget {
  const AppleWatchScreen({super.key});

  @override
  ConsumerState<AppleWatchScreen> createState() => _AppleWatchScreenState();
}

class _AppleWatchScreenState extends ConsumerState<AppleWatchScreen> {
  final List<HrvReading> _history = [];
  Timer? _ticker;
  int _secondsAgo = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_history.isNotEmpty && mounted) {
        setState(() {
          _secondsAgo = DateTime.now()
              .difference(_history.last.timestamp)
              .inSeconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Accumulate history as new readings arrive
    ref.listen<AsyncValue<HrvReading?>>(_hrvStreamProvider, (_, next) {
      next.whenData((reading) {
        if (reading != null) {
          final alreadyHave = _history.isNotEmpty &&
              _history.last.timestamp == reading.timestamp;
          if (!alreadyHave) {
            setState(() {
              _history.add(reading);
              if (_history.length > 20) _history.removeAt(0);
              _secondsAgo = 0;
            });
          }
        }
      });
    });

    final asyncHrv = ref.watch(_hrvStreamProvider);
    final isLoading = asyncHrv.isLoading;
    final latest = _history.isNotEmpty ? _history.last : null;
    final isIos = Platform.isIOS;

    return Scaffold(
      body: AppTheme.pageBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(isLoading: isLoading && isIos),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isIos) ...[
                        const _UnavailableCard(),
                      ] else ...[
                        _WatchStatusCard(
                          hasData: latest != null,
                          secondsAgo: _secondsAgo,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _HrvCard(reading: latest, secondsAgo: _secondsAgo),
                        if (_history.length >= 3) ...[
                          const SizedBox(height: AppSpacing.md),
                          _SparklineCard(readings: _history),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        const _AboutCard(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs, AppSpacing.sm, AppSpacing.lg, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.ink, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text('Heart Rate', style: AppType.h1),
          const Spacer(),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Watch status card ─────────────────────────────────────────────────────────

class _WatchStatusCard extends StatelessWidget {
  const _WatchStatusCard({required this.hasData, required this.secondsAgo});
  final bool hasData;
  final int secondsAgo;

  bool get _fresh => hasData && secondsAgo < 120; // within 2 min

  @override
  Widget build(BuildContext context) {
    final connected = _fresh;
    final statusColor =
        connected ? AppColors.connected : AppColors.notConnected;
    final statusBg = connected ? AppColors.okSoft : const Color(0xFFF5E4E4);
    final statusText = connected ? 'Connected' : 'Searching…';
    final statusIcon =
        connected ? Icons.check_circle_rounded : Icons.watch_off_rounded;

    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Icon(Icons.watch_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Apple Watch',
                    style: AppType.h2.copyWith(fontSize: 17)),
                const SizedBox(height: 2),
                Text('Reading from Apple Health',
                    style: AppType.label),
              ],
            ),
          ),
          Flexible(
           child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 13),
                const SizedBox(width: 4),
                Text(statusText,
                    style: AppType.label
                        .copyWith(color: statusColor, fontSize: 12)),
              ],
            ),
           ),
          ),
        ],
      ),
    );
  }
}

// ── Heart rate display card ───────────────────────────────────────────────────

class _HrvCard extends StatelessWidget {
  const _HrvCard({required this.reading, required this.secondsAgo});
  final HrvReading? reading;
  final int secondsAgo;

  static ({String label, Color color, Color bg}) _zone(double bpm) {
    if (bpm < 60) {
      return (
        label: 'Resting',
        color: AppColors.connected,
        bg: AppColors.okSoft
      );
    }
    if (bpm < 100) {
      return (
        label: 'Normal',
        color: AppColors.primary,
        bg: AppColors.primarySoft
      );
    }
    if (bpm < 140) {
      return (
        label: 'Elevated',
        color: AppColors.cue,
        bg: AppColors.warnSoft
      );
    }
    return (
      label: 'High Intensity',
      color: AppColors.notConnected,
      bg: const Color(0xFFF5E4E4)
    );
  }

  String get _age {
    if (reading == null) return '—';
    if (secondsAgo < 60) return '${secondsAgo}s ago';
    final m = secondsAgo ~/ 60;
    return '${m}m ago';
  }

  @override
  Widget build(BuildContext context) {
    final bpm = reading?.bpm;
    final z = bpm != null ? _zone(bpm) : null;

    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LIVE HEART RATE', style: AppType.label),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                bpm != null ? bpm.toStringAsFixed(0) : '—',
                style: const TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 72,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  height: 1.0,
                  letterSpacing: -3,
                ),
              ),
              if (bpm != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('BPM',
                      style: AppType.body.copyWith(
                          fontSize: 20, color: AppColors.inkSoft)),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (z != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: z.bg,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(z.label,
                      style: AppType.label.copyWith(
                          color: z.color, fontSize: 13)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.field,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text('Waiting for data…',
                      style: AppType.label.copyWith(
                          color: AppColors.inkFaint, fontSize: 13)),
                ),
              const Spacer(),
              Icon(Icons.schedule_rounded,
                  size: 13, color: AppColors.inkFaint),
              const SizedBox(width: 4),
              Text(_age, style: AppType.label.copyWith(fontSize: 12)),
            ],
          ),
          if (bpm == null) ...[
            const SizedBox(height: AppSpacing.lg),
            _GrantAccessButton(),
          ],
        ],
      ),
    );
  }
}

// ── Sparkline card ────────────────────────────────────────────────────────────

class _SparklineCard extends StatelessWidget {
  const _SparklineCard({required this.readings});
  final List<HrvReading> readings;

  @override
  Widget build(BuildContext context) {
    final spots = readings.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.bpm);
    }).toList();

    final minY = (readings.map((r) => r.bpm).reduce((a, b) => a < b ? a : b) - 10)
        .clamp(0.0, double.infinity);
    final maxY = readings.map((r) => r.bpm).reduce((a, b) => a > b ? a : b) + 10;

    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('RECENT READINGS', style: AppType.label),
              const Spacer(),
              Text('${readings.length} samples',
                  style: AppType.label.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, _, _) =>
                          FlDotCirclePainter(
                        radius: spot == spots.last ? 4 : 0,
                        color: AppColors.primary,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.12),
                          AppColors.primary.withValues(alpha: 0.01),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('oldest', style: AppType.label.copyWith(fontSize: 10)),
              Text('latest', style: AppType.label.copyWith(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── About heart rate card ─────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('Heart Rate Zones',
                  style:
                      AppType.h2.copyWith(fontSize: 16, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your Apple Watch measures heart rate continuously and syncs it to Apple Health. '
            'aria reads the latest value every 5 seconds so you can monitor your effort during a walk.',
            style: AppType.body.copyWith(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          _RangeRow(label: '< 60 BPM', desc: 'Resting',
              color: AppColors.connected),
          _RangeRow(label: '60–100 BPM', desc: 'Normal',
              color: AppColors.primary),
          _RangeRow(label: '100–140 BPM', desc: 'Elevated / active',
              color: AppColors.cue),
          _RangeRow(label: '> 140 BPM', desc: 'High intensity',
              color: AppColors.notConnected),
        ],
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({required this.label, required this.desc, required this.color});
  final String label;
  final String desc;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: AppType.label.copyWith(
                  color: AppColors.ink, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text('—', style: AppType.label),
          const SizedBox(width: 6),
          Text(desc, style: AppType.label),
        ],
      ),
    );
  }
}

// ── Grant access button ───────────────────────────────────────────────────────

class _GrantAccessButton extends StatefulWidget {
  @override
  State<_GrantAccessButton> createState() => _GrantAccessButtonState();
}

class _GrantAccessButtonState extends State<_GrantAccessButton> {
  bool _loading = false;
  String? _message;

  Future<void> _request() async {
    setState(() { _loading = true; _message = null; });
    final auth = await HrvService.requestAuth();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = switch (auth) {
        HrvAuthState.authorized => 'Access granted! Data will appear shortly.',
        HrvAuthState.denied     => 'Access denied. Enable in Settings → Health → aria.',
        HrvAuthState.unknown    => 'Channel not ready — try again in a moment.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loading ? null : _request,
            icon: _loading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.health_and_safety_rounded, size: 18),
            label: Text(_loading ? 'Requesting…' : 'Grant Health Access'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md)),
            ),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_message!,
              style: AppType.label.copyWith(
                  color: _message!.startsWith('Access granted')
                      ? AppColors.connected
                      : AppColors.notConnected,
                  height: 1.4)),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.inkFaint, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Make sure your Apple Watch is worn and syncing to Health.',
                style: AppType.label.copyWith(
                    color: AppColors.inkFaint, height: 1.4, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Android unavailable card ──────────────────────────────────────────────────

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: const Icon(Icons.watch_rounded,
                color: AppColors.inkFaint, size: 32),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Apple Watch',
              style: AppType.h2, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Live heart rate via Apple Watch is only available on iPhone. '
            'Open this app on your iPhone paired with an Apple Watch to use this feature.',
            style: AppType.body.copyWith(fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
