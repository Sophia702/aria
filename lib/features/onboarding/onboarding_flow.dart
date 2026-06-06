import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/sensor_status.dart';
import '../../data/persistence/app_prefs.dart';
import '../../providers/providers.dart';
import '../../widgets/aria_logo.dart';
import '../../widgets/body_view.dart';
import '../../widgets/gradient_button.dart';
import '../shell/main_shell.dart';

/// First-run onboarding: Landing → How aria helps → About you → Connect sensors
/// → Baseline walk → Home. Navigation is BUTTON-ONLY (no swipe) per the
/// no-fine-motor-gesture accessibility rule.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _Baseline { idle, walking, done }

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  static const _steps = 5;
  static const _baselineSecs = 12;

  int _step = 0;
  bool _speechAssist = false;

  final _name = TextEditingController(text: 'Margaret');
  final _age = TextEditingController();
  final _years = TextEditingController();
  final _meds = TextEditingController();
  final _contactType = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();

  _Baseline _baseline = _Baseline.idle;
  int _secsLeft = _baselineSecs;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [
      _name,
      _age,
      _years,
      _meds,
      _contactType,
      _contactName,
      _contactPhone
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() => setState(() => _step++);

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    }
  }

  Future<void> _finish() async {
    await AppPrefs.setOnboarded();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  void _startBaseline() {
    setState(() {
      _baseline = _Baseline.walking;
      _secsLeft = _baselineSecs;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secsLeft <= 1) {
        t.cancel();
        setState(() {
          _secsLeft = 0;
          _baseline = _Baseline.done;
        });
        Future.delayed(const Duration(milliseconds: 900), _finish);
      } else {
        setState(() => _secsLeft--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppTheme.pageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(step: _step, total: _steps, onBack: _step > 0 ? _back : null),
                const SizedBox(height: AppSpacing.lg),
                Expanded(child: _buildStep()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() => switch (_step) {
        0 => _landing(),
        1 => _howItHelps(),
        2 => _aboutYou(),
        3 => _connectSensors(),
        _ => _baselineWalk(),
      };

  // 01 — Landing.
  Widget _landing() {
    return Column(
      children: [
        const Spacer(),
        const AriaLogo(size: 64, showWordmark: false),
        const SizedBox(height: AppSpacing.lg),
        Text('aria', style: AppType.display.copyWith(fontSize: 48)),
        const SizedBox(height: AppSpacing.xs),
        Text("Keep your life's rhythm",
            style: AppType.body, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xl),
        _SpeechAssistToggle(
          value: _speechAssist,
          onChanged: (v) => setState(() => _speechAssist = v),
        ),
        const Spacer(),
        GradientButton(
            label: 'Get started', icon: Icons.arrow_forward_rounded, onPressed: _next),
      ],
    );
  }

  // 02 — How aria helps.
  Widget _howItHelps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How aria helps', style: AppType.h1),
        const SizedBox(height: AppSpacing.lg),
        const Expanded(
          child: Column(
            children: [
              _HelpPoint(
                  icon: Icons.sensors,
                  title: 'Senses your walk',
                  body: 'Wearable sensors read your gait in real time.'),
              SizedBox(height: AppSpacing.md),
              _HelpPoint(
                  icon: Icons.music_note,
                  title: 'Plays a beat',
                  body: 'A steady rhythm helps keep you moving smoothly.'),
              SizedBox(height: AppSpacing.md),
              _HelpPoint(
                  icon: Icons.auto_awesome,
                  title: 'Learns & adapts',
                  body: 'aria senses when you need support and steps in to help.'),
            ],
          ),
        ),
        GradientButton(label: 'Next', icon: Icons.arrow_forward_rounded, onPressed: _next),
      ],
    );
  }

  // 03 — About you.
  Widget _aboutYou() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About you', style: AppType.h1),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ListView(
            children: [
              _OnbField(label: 'Name', controller: _name),
              _OnbField(label: 'Age', controller: _age),
              _OnbField(label: 'Years since diagnosis', controller: _years),
              _OnbField(label: 'Medications (optional)', controller: _meds),
              _OnbField(
                  label: 'Emergency contact — relationship',
                  controller: _contactType),
              _OnbField(
                  label: 'Emergency contact — name', controller: _contactName),
              _OnbField(
                  label: 'Emergency contact — phone', controller: _contactPhone),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 18, color: AppColors.label),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'We ask for location only to share with your contact in an '
                      'emergency. Your data stays private.',
                      style: AppType.label.copyWith(color: AppColors.label),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GradientButton(label: 'Continue', icon: Icons.arrow_forward_rounded, onPressed: _next),
      ],
    );
  }

  // 04 — Connect sensors.
  Widget _connectSensors() {
    final sensors = ref.watch(sensorSourceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connect sensors', style: AppType.h1),
        const SizedBox(height: AppSpacing.xs),
        Text('Place a sensor on your lower back and each ankle, then tap to pair.',
            style: AppType.body),
        Expanded(
          child: StreamBuilder<SensorStatusMap>(
            stream: sensors.status,
            initialData: sensors.statusNow,
            builder: (context, snap) {
              final status = snap.data ?? SensorStatusMap.allNotConnected();
              return Column(
                children: [
                  Expanded(
                    child: BodyView(
                      status: status,
                      onTap: (loc) => sensors.connect(loc),
                    ),
                  ),
                  if (!status.allConnected)
                    OutlinedButton(
                      onPressed: () => sensors.connectAll(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.pill)),
                      ),
                      child: Text('Connect all',
                          style: AppType.button.copyWith(color: AppColors.primary)),
                    )
                  else
                    GradientButton(
                        label: 'Next',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _next),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // 05 — Baseline walk.
  Widget _baselineWalk() {
    final progress = (_baselineSecs - _secsLeft) / _baselineSecs;
    final (label, onTap) = switch (_baseline) {
      _Baseline.idle => ('Start', _startBaseline),
      _Baseline.walking => ('Walking…', null),
      _Baseline.done => ('Complete ✓', null),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Baseline walk', style: AppType.h1),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Take a few steps so aria can learn your natural pace.',
            style: AppType.body, textAlign: TextAlign.center),
        const Spacer(),
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: _baseline == _Baseline.idle ? 0 : progress,
                  strokeWidth: 12,
                  backgroundColor: AppColors.surfaceDeep,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              Text(
                _baseline == _Baseline.done ? '✓' : '$_secsLeft',
                style: AppType.display.copyWith(fontSize: 64),
              ),
            ],
          ),
        ),
        const Spacer(),
        GradientButton(
            label: label, icon: Icons.directions_walk, onPressed: onTap),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.step, required this.total, required this.onBack});
  final int step;
  final int total;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          Semantics(
            button: true,
            label: 'Back',
            child: Material(
              color: AppColors.card,
              shape: const CircleBorder(),
              child: InkResponse(
                onTap: onBack,
                radius: 26,
                child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.arrow_back_rounded, color: AppColors.ink)),
              ),
            ),
          ),
        const Spacer(),
        Row(
          children: [
            for (var i = 0; i < total; i++)
              Container(
                margin: const EdgeInsets.only(left: 6),
                width: i == step ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == step ? AppColors.primary : AppColors.surfaceDeep,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
        const Spacer(),
        if (onBack != null) const SizedBox(width: 48),
      ],
    );
  }
}

class _SpeechAssistToggle extends StatelessWidget {
  const _SpeechAssistToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: AppTheme.cardDecoration(radius: AppRadii.pill),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Speech assist', style: AppType.h2.copyWith(fontSize: 17)),
                Text('Hands-free voice mode', style: AppType.label),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _HelpPoint extends StatelessWidget {
  const _HelpPoint(
      {required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.h2.copyWith(fontSize: 18)),
                const SizedBox(height: 2),
                Text(body, style: AppType.body.copyWith(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnbField extends StatelessWidget {
  const _OnbField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.label.copyWith(color: AppColors.inkSoft)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            style: AppType.h2.copyWith(fontSize: 18),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
