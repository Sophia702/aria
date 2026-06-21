import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/walk_session.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';

enum _SortOrder { latestFirst, oldestFirst, longestSession, mostSteps }

class AllSessionsScreen extends ConsumerStatefulWidget {
  const AllSessionsScreen({super.key});
  @override
  ConsumerState<AllSessionsScreen> createState() => _AllSessionsScreenState();
}

class _AllSessionsScreenState extends ConsumerState<AllSessionsScreen> {
  _SortOrder _sort = _SortOrder.latestFirst;

  List<WalkSession> _sortedFrom(List<WalkSession> input) {
    final list = List<WalkSession>.from(input);
    switch (_sort) {
      case _SortOrder.latestFirst:
        list.sort((a, b) => b.startedAtMs.compareTo(a.startedAtMs));
      case _SortOrder.oldestFirst:
        list.sort((a, b) => a.startedAtMs.compareTo(b.startedAtMs));
      case _SortOrder.longestSession:
        list.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
      case _SortOrder.mostSteps:
        list.sort((a, b) => b.steps.compareTo(a.steps));
    }
    return list;
  }

  static String _label(WalkSession s) {
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
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(sessionHistoryProvider).asData?.value ?? const [];
    final sessions = _sortedFrom(all);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.allSessions ?? 'All sessions'),
        backgroundColor: AppColors.bgTop,
        foregroundColor: AppColors.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          PopupMenuButton<_SortOrder>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _SortOrder.latestFirst,
                child: Text(l10n?.sortLatest ?? 'Latest first'),
              ),
              PopupMenuItem(
                value: _SortOrder.oldestFirst,
                child: Text(l10n?.sortOldest ?? 'Oldest first'),
              ),
              PopupMenuItem(
                value: _SortOrder.longestSession,
                child: Text(l10n?.sortLongest ?? 'Longest first'),
              ),
              PopupMenuItem(
                value: _SortOrder.mostSteps,
                child: Text(l10n?.sortMostSteps ?? 'Most steps'),
              ),
            ],
          ),
        ],
      ),
      body: AppTheme.pageBackground(
        child: sessions.isEmpty
            ? Center(
                child: Text(
                  l10n?.noWalksRecorded ?? 'No walks recorded yet.',
                  style: AppType.body,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
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
                                shape: BoxShape.circle),
                            child: const Icon(Icons.directions_walk,
                                color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_label(session),
                                    style: AppType.h2.copyWith(fontSize: 16)),
                                Text(
                                    '${session.steps} steps · ${session.duration.inMinutes}m',
                                    style: AppType.label),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: AppColors.inkFaint),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
