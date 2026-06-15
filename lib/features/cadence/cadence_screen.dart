import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../providers/providers.dart';
import '../../services/cadence/cadence_service.dart';
import '../../services/cue/metronome_cue_engine.dart';
import '../../services/sensors/arduino_ble_service.dart';

class CadenceScreen extends ConsumerStatefulWidget {
  const CadenceScreen({super.key});

  @override
  ConsumerState<CadenceScreen> createState() => _CadenceScreenState();
}

class _CadenceScreenState extends ConsumerState<CadenceScreen>
    with SingleTickerProviderStateMixin {
  late final CadenceService _cadence;
  late final MetronomeCueEngine _beat;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  static const _stabilizeDuration = 5;

  bool _tracking = false;
  bool _stabilizing = false;
  int _stabilizeSecondsLeft = _stabilizeDuration;
  bool _beatOn = false;
  double _volume = 0.8;
  BeatSound _sound = BeatSound.bell;
  double _displayedSpm = 0;
  int _stepCount = 0;
  double _lastSetBpm = 0;

  StreamSubscription? _cadenceSub;
  StreamSubscription? _stepSub;
  StreamSubscription? _bleSub;
  Timer? _stabilizeTimer;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    final ble = ref.read(arduinoBleProvider);
    _cadence = CadenceService(ble);
    _beat = MetronomeCueEngine();
    _beat.init();

    _cadenceSub = _cadence.onCadence.listen((spm) {
      if (!mounted) return;
      setState(() => _displayedSpm = spm);
      // Only update beat tempo after stabilization and if change is ≥10 SPM.
      if (_beatOn && !_stabilizing && (spm - _lastSetBpm).abs() >= 10) {
        _lastSetBpm = spm;
        _beat.setTempo(spm);
      }
    });

    _stepSub = _cadence.onStep.listen((_) {
      if (!mounted) return;
      setState(() => _stepCount = _cadence.stepCount);
      _pulseCtrl.forward(from: 0);
    });

    _bleSub = ble.onChange.listen((_) {
      if (!mounted) return;
      setState(() {});
      if (ble.state != ArduinoBleState.connected && _tracking) {
        _stopTracking();
      }
    });
  }

  @override
  void dispose() {
    _stabilizeTimer?.cancel();
    _cadenceSub?.cancel();
    _stepSub?.cancel();
    _bleSub?.cancel();
    _cadence.dispose();
    _beat.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _startTracking() {
    setState(() {
      _tracking = true;
      _stabilizing = true;
      _stabilizeSecondsLeft = _stabilizeDuration;
      _displayedSpm = 0;
      _stepCount = 0;
      _lastSetBpm = 0;
    });
    _cadence.start();

    _stabilizeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final next = _stabilizeSecondsLeft - 1;
      setState(() => _stabilizeSecondsLeft = next);
      if (next <= 0) {
        t.cancel();
        _endStabilization();
      }
    });
  }

  Future<void> _endStabilization() async {
    setState(() => _stabilizing = false);
    // Auto-start beat at measured cadence if toggle is already on.
    if (_beatOn && _displayedSpm > 0) {
      _lastSetBpm = _displayedSpm;
      await _beat.startCue(bpm: _displayedSpm);
    }
  }

  void _stopTracking() {
    _stabilizeTimer?.cancel();
    _stabilizeTimer = null;
    setState(() {
      _tracking = false;
      _stabilizing = false;
    });
    _cadence.stop();
    if (_beatOn) _disableBeat();
  }

  Future<void> _toggleBeat() async {
    if (_beatOn) {
      await _disableBeat();
    } else {
      setState(() => _beatOn = true);
      // Don't start the player yet if still in stabilization period.
      if (!_stabilizing) {
        final bpm = _displayedSpm > 0 ? _displayedSpm : 100.0;
        _lastSetBpm = bpm;
        await _beat.startCue(bpm: bpm);
      }
    }
  }

  Future<void> _disableBeat() async {
    await _beat.stopCue();
    setState(() => _beatOn = false);
  }

  Future<void> _changeSound(BeatSound sound) async {
    setState(() => _sound = sound);
    await _beat.setSound(sound);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ble = ref.read(arduinoBleProvider);
    final connected = ble.state == ArduinoBleState.connected;

    return Scaffold(
      backgroundColor: AppColors.bgTop,
      appBar: AppBar(
        backgroundColor: AppColors.bgTop,
        elevation: 0,
        centerTitle: false,
        title: Text('Cadence Tracker', style: AppType.h2),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CadenceOrb(
                spm: _displayedSpm,
                tracking: _tracking,
                stabilizing: _stabilizing,
                secondsLeft: _stabilizeSecondsLeft,
                pulseAnim: _pulseAnim,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: _StepChip(count: _stepCount, active: _tracking),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!connected)
                const _NotConnectedCard()
              else ...[
                _TrackButton(
                  tracking: _tracking,
                  stabilizing: _stabilizing,
                  onTap: _tracking ? _stopTracking : _startTracking,
                ),
                const SizedBox(height: AppSpacing.md),
                _BeatCard(
                  beatOn: _beatOn,
                  volume: _volume,
                  sound: _sound,
                  canToggle: _tracking,
                  stabilizing: _stabilizing,
                  onToggle: _tracking ? _toggleBeat : null,
                  onVolume: (v) async {
                    setState(() => _volume = v);
                    await _beat.setVolume(v);
                  },
                  onSound: _changeSound,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _CadenceOrb extends StatelessWidget {
  const _CadenceOrb({
    required this.spm,
    required this.tracking,
    required this.stabilizing,
    required this.secondsLeft,
    required this.pulseAnim,
  });
  final double spm;
  final bool tracking;
  final bool stabilizing;
  final int secondsLeft;
  final Animation<double> pulseAnim;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: pulseAnim,
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primary.withValues(alpha: stabilizing ? 0.10 : 0.18),
                AppColors.primary.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(
              color: AppColors.primary.withValues(
                  alpha: tracking ? (stabilizing ? 0.35 : 0.55) : 0.20),
              width: 2,
            ),
          ),
          child: stabilizing
              ? _StabilizingContent(secondsLeft: secondsLeft)
              : _SpmContent(spm: spm),
        ),
      ),
    );
  }
}

class _SpmContent extends StatelessWidget {
  const _SpmContent({required this.spm});
  final double spm;

  @override
  Widget build(BuildContext context) {
    final label = spm > 0 ? spm.round().toString() : '--';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: kFontFamily,
            fontSize: 72,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -3,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'SPM',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _StabilizingContent extends StatelessWidget {
  const _StabilizingContent({required this.secondsLeft});
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$secondsLeft',
          style: const TextStyle(
            fontFamily: kFontFamily,
            fontSize: 64,
            fontWeight: FontWeight.w800,
            color: AppColors.inkSoft,
            letterSpacing: -2,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Calibrating…',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'walk naturally',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 11,
            color: AppColors.inkFaint,
          ),
        ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.count, required this.active});
  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: active ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_walk_rounded,
                color: AppColors.primary, size: 15),
            const SizedBox(width: 6),
            Text(
              '$count steps',
              style: const TextStyle(
                fontFamily: kFontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackButton extends StatelessWidget {
  const _TrackButton({
    required this.tracking,
    required this.stabilizing,
    required this.onTap,
  });
  final bool tracking;
  final bool stabilizing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = stabilizing
        ? 'Stop'
        : tracking
            ? 'Stop Tracking'
            : 'Start Tracking';
    final icon = tracking ? Icons.stop_rounded : Icons.play_arrow_rounded;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: tracking
              ? null
              : const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDeep],
                ),
          color: tracking ? AppColors.field : null,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: tracking ? Border.all(color: AppColors.lineSoft) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: tracking ? AppColors.inkSoft : Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tracking ? AppColors.inkSoft : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeatCard extends StatelessWidget {
  const _BeatCard({
    required this.beatOn,
    required this.volume,
    required this.sound,
    required this.canToggle,
    required this.stabilizing,
    required this.onToggle,
    required this.onVolume,
    required this.onSound,
  });
  final bool beatOn;
  final double volume;
  final BeatSound sound;
  final bool canToggle;
  final bool stabilizing;
  final VoidCallback? onToggle;
  final ValueChanged<double> onVolume;
  final ValueChanged<BeatSound> onSound;

  @override
  Widget build(BuildContext context) {
    final subtitle = stabilizing
        ? 'Will start after calibration'
        : canToggle
            ? 'Play a click at your cadence'
            : 'Start tracking to enable';

    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: beatOn ? AppColors.primarySoft : AppColors.field,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: beatOn ? AppColors.primary : AppColors.inkFaint,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Beat sync',
                        style: AppType.h2.copyWith(fontSize: 16)),
                    Text(subtitle, style: AppType.label),
                  ],
                ),
              ),
              Switch(
                value: beatOn,
                onChanged: canToggle ? (_) => onToggle?.call() : null,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primarySoft,
              ),
            ],
          ),
          if (beatOn && !stabilizing) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.lineSoft),
            const SizedBox(height: AppSpacing.md),
            // ── Sound picker ──────────────────────────────────────────
            Wrap(
              spacing: 8,
              children: [
                _SoundChip(
                  label: 'Click',
                  icon: Icons.radio_button_checked_rounded,
                  selected: sound == BeatSound.click,
                  onTap: () => onSound(BeatSound.click),
                ),
                _SoundChip(
                  label: 'Bell',
                  icon: Icons.notifications_rounded,
                  selected: sound == BeatSound.bell,
                  onTap: () => onSound(BeatSound.bell),
                ),
                _SoundChip(
                  label: 'Woodblock',
                  icon: Icons.forest_rounded,
                  selected: sound == BeatSound.woodblock,
                  onTap: () => onSound(BeatSound.woodblock),
                ),
                _SoundChip(
                  label: 'Chiptune',
                  icon: Icons.videogame_asset_rounded,
                  selected: sound == BeatSound.chiptune,
                  onTap: () => onSound(BeatSound.chiptune),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.lineSoft),
            const SizedBox(height: AppSpacing.md),
            // ── Volume slider ─────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.volume_down_rounded,
                    color: AppColors.inkSoft, size: 18),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      thumbColor: AppColors.primary,
                      inactiveTrackColor: AppColors.primarySoft,
                    ),
                    child: Slider(
                      value: volume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      onChanged: onVolume,
                    ),
                  ),
                ),
                const Icon(Icons.volume_up_rounded,
                    color: AppColors.inkSoft, size: 18),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SoundChip extends StatelessWidget {
  const _SoundChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.field,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? Colors.white : AppColors.inkSoft),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotConnectedCard extends StatelessWidget {
  const _NotConnectedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.bluetooth_disabled_rounded,
              color: AppColors.inkFaint, size: 40),
          const SizedBox(height: AppSpacing.sm),
          Text('Arduino not connected',
              style: AppType.h2.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Connect the Nano 33 BLE Sense\nfrom the IMU dashboard first.',
            style: AppType.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
