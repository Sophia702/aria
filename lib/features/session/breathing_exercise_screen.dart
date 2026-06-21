import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Full-screen guided breathing. A large circle expands on "Breathe in" and
/// contracts on "Breathe out" (4-phase box breath). The user can leave with the
/// back arrow or the "I'm feeling better, continue" button (which pops `true`).
class BreathingExerciseScreen extends StatefulWidget {
  const BreathingExerciseScreen({super.key});

  @override
  State<BreathingExerciseScreen> createState() =>
      _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _phase(double v) {
    if (v < 0.25) return 'Breathe in';
    if (v < 0.50) return 'Hold';
    if (v < 0.75) return 'Breathe out';
    return 'Hold';
  }

  double _scale(double v) {
    if (v < 0.25) return 0.6 + (v / 0.25) * 0.4; // grow 0.6 → 1.0
    if (v < 0.50) return 1.0; // hold big
    if (v < 0.75) return 1.0 - ((v - 0.50) / 0.25) * 0.4; // shrink 1.0 → 0.6
    return 0.6; // hold small
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    final size = MediaQuery.of(context).size;
    final maxCircle = size.width * 0.8;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.walkingWash),
        child: SafeArea(
          child: Stack(
            children: [
              // Back arrow.
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              // Breathing circle filling the screen.
              Center(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final v = _ctrl.value;
                    final scale = reduced ? 1.0 : _scale(v);
                    return SizedBox(
                      width: maxCircle,
                      height: maxCircle,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: scale,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.22),
                                    Colors.white.withValues(alpha: 0.04),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: scale * 0.7,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                          ),
                          Text(
                            reduced ? 'Breathe' : _phase(v),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              fontFamily: kFontFamily,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Guidance + continue button.
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Follow the circle. In through your nose, out through '
                        'your mouth.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 16,
                          height: 1.4,
                          fontFamily: kFontFamily,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(true),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text("I'm feeling better, continue"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(56),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              fontFamily: kFontFamily,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                            ),
                          ),
                        ),
                      ),
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
