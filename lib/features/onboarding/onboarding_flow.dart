import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/sensor_status.dart';
import '../../data/persistence/app_prefs.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../services/medication/medication_search.dart';
import '../../services/voice/voice_controller.dart';
import '../../widgets/aria_logo.dart';
import '../../widgets/body_view.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/profile_fields.dart';
import '../shell/main_shell.dart';

/// First-run onboarding. Navigation is BUTTON-ONLY (no swipe) per the
/// no-fine-motor-gesture accessibility rule.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _Baseline { idle, walking, done }

class _OnboardingFlowState extends ConsumerState<OnboardingFlow>
    with SingleTickerProviderStateMixin {
  static const _steps = 5;
  static const _baselineSecs = 12;

  int _step = 0;
  bool _speechAssist = false;

  final _name = TextEditingController();
  final _clinician = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();

  DateTime? _birthdate;
  List<String> _meds = [];
  String? _relationship;
  String _dialCode = '+1';

  _Baseline _baseline = _Baseline.idle;

  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _baselineSecs),
  );
  late final Animation<double> _animProgress = CurvedAnimation(
    parent: _animController,
    curve: Curves.linear,
  );

  @override
  void dispose() {
    _animController.dispose();
    for (final c in [_name, _clinician, _contactName, _contactPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() => setState(() => _step++);

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    await AppPrefs.saveProfile({
      'name': _name.text.trim(),
      'birthdate': _birthdate == null ? '' : _isoDate(_birthdate!),
      'meds': MedicationSearch.encode(_meds),
      'clinician': _clinician.text.trim(),
      'contactType': _relationship ?? '',
      'contactName': _contactName.text.trim(),
      'contactPhoneCode': _dialCode,
      'contactPhone': _contactPhone.text.trim(),
    });
    ref.invalidate(userNameProvider);
    await AppPrefs.setOnboarded();
    await AppPrefs.setVoiceEnabled(_speechAssist);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
    if (_speechAssist) {
      ref.read(voiceControllerProvider.notifier).enable();
    }
  }

  void _startBaseline() {
    setState(() => _baseline = _Baseline.walking);
    _animController.forward(from: 0);
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _baseline = _Baseline.done);
        Future.delayed(const Duration(milliseconds: 900), _finish);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: AppTheme.pageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                    step: _step,
                    total: _steps,
                    onBack: _step > 0 ? _back : null),
                const SizedBox(height: AppSpacing.lg),
                Expanded(child: _buildStep(l10n)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(AppLocalizations? l10n) => switch (_step) {
        0 => _landing(l10n),
        1 => _howItHelps(l10n),
        2 => _aboutYou(l10n),
        3 => _connectSensors(l10n),
        _ => _baselineWalk(l10n),
      };

  // Step 0 — Landing.
  Widget _landing(AppLocalizations? l10n) {
    return Column(
      children: [
        const Spacer(),
        const AriaLogo(size: 64, showWordmark: false),
        const SizedBox(height: AppSpacing.lg),
        // "aria" wordmark in Newsreader italic.
        Text(
          'aria',
          style: AppType.displaySerif.copyWith(fontSize: 50),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n?.tagline ?? "Keep your life's rhythm",
          style: AppType.body.copyWith(
              fontWeight: FontWeight.w500, color: AppColors.inkSoft),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        _SpeechAssistButton(
          value: _speechAssist,
          onTap: () {
            setState(() => _speechAssist = !_speechAssist);
            AppPrefs.setVoiceEnabled(!_speechAssist);
          },
        ),
        const Spacer(),
        GradientButton(
            label: l10n?.getStarted ?? 'Get started',
            icon: Icons.arrow_forward_rounded,
            onPressed: _next),
      ],
    );
  }

  // Step 1 — How aria helps.
  Widget _howItHelps(AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n?.howHelps ?? 'How aria helps', style: AppType.h1),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: Column(
            children: [
              _HelpPoint(
                icon: Icons.sensors,
                title: l10n?.sensesWalk ?? 'Senses your walk',
                body: 'Wearable sensors read your gait in real time.',
                gradient: const LinearGradient(
                  colors: [Color(0xFF164D3C), Color(0xFF4E9A57)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _HelpPoint(
                icon: Icons.music_note,
                title: l10n?.playsABeat ?? 'Plays a beat',
                body: 'A steady rhythm helps keep you moving smoothly.',
                gradient: const LinearGradient(
                  colors: [Color(0xFF8E3E48), Color(0xFFC4687A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _HelpPoint(
                icon: Icons.auto_awesome,
                title: l10n?.learnsAdapts ?? 'Learns & adapts',
                body: 'aria senses when you need support and steps in to help.',
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F5C49), Color(0xFF6E978A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ],
          ),
        ),
        GradientButton(
            label: l10n?.next ?? 'Next',
            icon: Icons.arrow_forward_rounded,
            onPressed: _next),
      ],
    );
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Step 2 — About you. Same fields as the Profile page; saved together so
  // editing here or there keeps everything in sync.
  Widget _aboutYou(AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n?.aboutYou ?? 'About you', style: AppType.h1),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ListView(
            children: [
              _OnbSection(
                title: l10n?.personalInfo ?? 'Personal information',
                children: [
                  LabeledTextField(
                      label: l10n?.fieldName ?? 'Name', controller: _name),
                  BirthdateField(
                    date: _birthdate,
                    onChanged: (d) => setState(() => _birthdate = d),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _OnbSection(
                title: l10n?.medicalInfo ?? 'Medical information',
                children: [
                  MedicationField(
                    meds: _meds,
                    onChanged: (m) => setState(() => _meds = m),
                  ),
                  LabeledTextField(
                      label: l10n?.clinicianOptional ??
                          'Assigned clinician (optional)',
                      controller: _clinician),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _OnbSection(
                title: l10n?.emergencyContact ?? 'Emergency contact',
                children: [
                  RelationshipDropdown(
                    value: _relationship,
                    onChanged: (v) => setState(() => _relationship = v),
                  ),
                  LabeledTextField(
                      label: l10n?.fieldName ?? 'Name',
                      controller: _contactName),
                  PhoneField(
                    dialCode: _dialCode,
                    controller: _contactPhone,
                    onCodeChanged: (v) =>
                        setState(() => _dialCode = v ?? '+1'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 18, color: AppColors.inkFaint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your information is stored only on this device and kept '
                      'private. It is never uploaded or shared.',
                      style:
                          AppType.label.copyWith(color: AppColors.inkFaint),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GradientButton(
            label: l10n?.continueBtn ?? 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: _next),
      ],
    );
  }

  // Step 3 — Connect sensors.
  Widget _connectSensors(AppLocalizations? l10n) {
    final sensors = ref.watch(sensorSourceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n?.connectSensors ?? 'Connect sensors', style: AppType.h1),
        const SizedBox(height: AppSpacing.xs),
        Text(
            'Place a sensor on your lower back and each ankle, then tap to pair.',
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
                  // Connect-all is optional; the user can always continue even
                  // with nothing connected (e.g. setting up before the sensor).
                  if (!status.allConnected) ...[
                    OutlinedButton(
                      onPressed: () => sensors.connectAll(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadii.pill)),
                      ),
                      child: Text(l10n?.connectAll ?? 'Connect all',
                          style: AppType.button
                              .copyWith(color: AppColors.primary)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  GradientButton(
                      label: l10n?.continueBtn ?? 'Continue',
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

  // Step 4 — Baseline walk.
  Widget _baselineWalk(AppLocalizations? l10n) {
    final totalMins = (_baselineSecs ~/ 60).toString();
    final totalSecs = (_baselineSecs % 60).toString().padLeft(2, '0');

    final (label, onTap) = switch (_baseline) {
      _Baseline.idle => ('Start', _startBaseline),
      _Baseline.walking => ('Walking…', null),
      _Baseline.done => ('Complete', null),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(l10n?.baselineWalk ?? 'Baseline walk', style: AppType.h1),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Take a few steps so aria can learn your natural pace.',
            style: AppType.body, textAlign: TextAlign.center),
        const Spacer(),
        Center(
          child: AnimatedBuilder(
            animation: _animProgress,
            builder: (context, _) {
              final elapsed = (_animProgress.value * _baselineSecs).round();
              final elapsedMins = (elapsed ~/ 60).toString();
              final elapsedSecs = (elapsed % 60).toString().padLeft(2, '0');
              return SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: CircularProgressIndicator(
                        value: _baseline == _Baseline.idle ? 0 : _animProgress.value,
                        strokeWidth: 14,
                        backgroundColor: AppColors.surfaceDeep,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                    if (_baseline == _Baseline.done)
                      const Icon(Icons.check_rounded,
                          size: 72, color: AppColors.primary)
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$elapsedMins:$elapsedSecs',
                            style: AppType.h2.copyWith(
                                fontSize: 44, letterSpacing: -1.0),
                          ),
                          Text(
                            'of $totalMins:$totalSecs',
                            style: AppType.label.copyWith(
                                fontSize: 16, color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const Spacer(),
        GradientButton(
            label: label,
            icon: Icons.directions_walk,
            onPressed: onTap),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.step, required this.total, required this.onBack});
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
                    child:
                        Icon(Icons.arrow_back_rounded, color: AppColors.ink)),
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

/// Full-width burgundy speech-assist button for the landing step.
class _SpeechAssistButton extends StatelessWidget {
  const _SpeechAssistButton({required this.value, required this.onTap});
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: 'Speech assist — hands-free voice mode',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          decoration: BoxDecoration(
            color: value ? AppColors.accent : AppColors.accentSoft,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: value ? Colors.white : AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n?.speechAssist ?? 'Speech assist',
                      style: AppType.h2.copyWith(
                        fontSize: 17,
                        color: value ? Colors.white : AppColors.accent,
                      ),
                    ),
                    Text(
                      l10n?.speechAssistSub ?? 'Hands-free voice mode',
                      style: AppType.label.copyWith(
                        color: value
                            ? Colors.white.withValues(alpha: 0.75)
                            : AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: value ? Colors.white : AppColors.accent,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpPoint extends StatelessWidget {
  const _HelpPoint({
    required this.icon,
    required this.title,
    required this.body,
    required this.gradient,
  });
  final IconData icon;
  final String title;
  final String body;
  final LinearGradient gradient;

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
              gradient: gradient,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
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

/// Card section wrapper for the onboarding "About you" form (matches Profile).
class _OnbSection extends StatelessWidget {
  const _OnbSection({required this.title, required this.children});
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

