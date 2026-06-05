import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/sensor_status.dart';
import '../../providers/providers.dart';
import '../../widgets/aria_logo.dart';
import '../../widgets/pulse_ring.dart';
import '../session/start_walk.dart';

/// Screen 06 — Home tab. Logo, greeting, the pulsing start-walk ring, and a
/// sensor-ready chip.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.name = 'Margaret'});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensors = ref.watch(sensorSourceProvider);
    // Scroll-safe: the column centres the ring when there's room and scrolls
    // on short screens instead of overflowing.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          const AriaLogo(size: 38),
          const SizedBox(height: AppSpacing.xl),
          Text('Welcome,', style: AppType.h1),
          Text(name, style: AppType.display),
          const SizedBox(height: AppSpacing.sm),
          Text('Ready to take a mindful walk?', style: AppType.body),
          const Spacer(),
          Center(
            child: Semantics(
              button: true,
              label: 'Start walk',
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => startWalk(context, ref),
                  child: PulseRing(
                    color: AppColors.clay,
                    size: 248,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.directions_walk,
                            color: Colors.white, size: 46),
                        SizedBox(height: 6),
                        Text('Start walk',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Center(
            child: StreamBuilder<SensorStatusMap>(
              stream: sensors.status,
              initialData: sensors.statusNow,
              builder: (context, snap) {
                final s = snap.data ?? SensorStatusMap.allNotConnected();
                return _SensorStatusChip(
                  connected: s.connectedCount,
                  total: SensorStatusMap.allNotConnected().states.length,
                  ready: s.allConnected,
                );
              },
            ),
          ),
                const SizedBox(height: AppSpacing.navClearance),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SensorStatusChip extends StatelessWidget {
  const _SensorStatusChip({
    required this.connected,
    required this.total,
    required this.ready,
  });
  final int connected;
  final int total;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready ? AppColors.connected : AppColors.label;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ready ? Icons.check_circle : Icons.sensors, color: color, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Text(
            ready ? 'Sensors ready' : '$connected of $total sensors connected',
            style: AppType.label.copyWith(color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}
