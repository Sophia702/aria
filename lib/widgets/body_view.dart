import 'package:flutter/material.dart';

import '../core/a11y/a11y.dart';
import '../core/sensor_schema.dart';
import '../core/theme/tokens.dart';
import '../data/models/sensor_status.dart';

/// Body view for the Connect-sensors screen: a full-body silhouette that gently
/// turns (a pseudo-3D sway), with the 3 sensor placements — lower back and BOTH
/// ankles — sitting on the figure. Each is a tappable status dot.
///
/// NOTE: this is a 2D silhouette with a 3D-style turn. A true textured rotating
/// 3D model would use a `.glb` asset via `model_viewer_plus` / `flutter_3d_controller`;
/// drop a humanoid model in assets and swap the painter for that when available.
class BodyView extends StatelessWidget {
  const BodyView({super.key, required this.status, required this.onTap});

  final SensorStatusMap status;
  final ValueChanged<SensorLocation> onTap;

  // Sensor placements over the figure (fractional -> Alignment).
  static const _spots = {
    SensorLocation.lowerBack: Alignment(0.0, 0.02),
    SensorLocation.ankleLeft: Alignment(-0.13, 0.72),
    SensorLocation.ankleRight: Alignment(0.13, 0.72),
  };

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Clean full-body figure on a soft rounded card.
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                border: Border.all(color: AppColors.line),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 20),
              child: Image.asset(
                'assets/images/aria_body.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Sensor markers.
          for (final loc in SensorLocation.values)
            Align(
              alignment: _spots[loc]!,
              child: _SensorDot(
                location: loc,
                state: status.of(loc),
                onTap: () => onTap(loc),
              ),
            ),
        ],
      ),
    );
  }
}

class _SensorDot extends StatelessWidget {
  const _SensorDot(
      {required this.location, required this.state, required this.onTap});
  final SensorLocation location;
  final SensorConnState state;
  final VoidCallback onTap;

  Color get _color => switch (state) {
        SensorConnState.connected => AppColors.connected,
        SensorConnState.pairing => AppColors.cue,
        SensorConnState.notConnected => AppColors.notConnected,
      };

  IconData get _icon => switch (state) {
        SensorConnState.connected => Icons.check,
        SensorConnState.pairing => Icons.bluetooth_searching,
        SensorConnState.notConnected => Icons.add,
      };

  String get _statusLabel => switch (state) {
        SensorConnState.connected => 'Connected',
        SensorConnState.pairing => 'Pairing…',
        SensorConnState.notConnected => 'Tap to connect',
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${location.label}, $_statusLabel',
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: A11y.minTapTarget,
                height: A11y.minTapTarget,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: _color, width: 3),
                  boxShadow: AppShadows.card,
                ),
                child: Icon(_icon, color: _color, size: 24),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  boxShadow: AppShadows.card,
                ),
                child: Text(location.label,
                    style: AppType.label.copyWith(fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
