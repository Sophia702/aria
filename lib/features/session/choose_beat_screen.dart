import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/a11y/a11y.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../widgets/equalizer_bars.dart';
import '../../widgets/gradient_button.dart';
import 'walking_screen.dart';
import 'package:just_audio/just_audio.dart';

class ChooseBeatScreen extends ConsumerStatefulWidget {
  const ChooseBeatScreen({super.key});

  @override
  ConsumerState<ChooseBeatScreen> createState() => _ChooseBeatScreenState();
}

class _ChooseBeatScreenState extends ConsumerState<ChooseBeatScreen> {
  static const _beats = [
    (name: 'Gentle Waltz',    sub: 'Gentle and graceful',  bpm: 77,  file: 'assets/sounds/Valse Gymnopedie (77 bpm).wav'),
    (name: 'Easy Flow',       sub: 'Easy flowing pace',    bpm: 80,  file: 'assets/sounds/Infinite Perspective (80 bpm).wav'),
    (name: 'Evening Stroll',  sub: 'Calm evening walk',    bpm: 101, file: 'assets/sounds/Evening (101 bpm).wav'),
    (name: 'Upbeat Stride',   sub: 'Upbeat and energetic', bpm: 116, file: 'assets/sounds/Kawai Kitsune (116 bpm).wav'),
  ];

  int _beatSelected = 0;
  bool _songsTab = false;
  final _previewPlayer = AudioPlayer();

  Future<void> _previewBeat(int index) async {
    setState(() => _beatSelected = index);
    await _previewPlayer.stop();
    await _previewPlayer.setAsset(_beats[index].file);
    await _previewPlayer.setLoopMode(LoopMode.one);
    await _previewPlayer.play();
  }

  Future<void> _choose(AppLocalizations? l10n) async {
    await _previewPlayer.stop();
    final bpm = _beats[_beatSelected].bpm.toDouble();
    final soundFile = _beats[_beatSelected].file;
    await ref.read(sessionControllerProvider.notifier).startSession(bpm: bpm);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => WalkingScreen(soundFile: soundFile)),
    );
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
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
                Row(
                  children: [
                    _BackButton(),
                    const SizedBox(width: AppSpacing.sm),
                    Text(l10n?.chooseYourBeat ?? 'Choose your beat',
                        style: AppType.h2),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SegmentedTabs(
                  songs: _songsTab,
                  beatsLabel: l10n?.beatsTab ?? 'Beats',
                  songsLabel: l10n?.songsTab ?? 'Songs',
                  onSelect: (s) async {
                    await _previewPlayer.stop();
                    setState(() => _songsTab = s);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: _songsTab
                      ? const _ComingSoon()
                      : ListView.builder(
                          itemCount: _beats.length,
                          itemBuilder: (context, i) => _BeatTile(
                            name: _beats[i].name,
                            sub: _beats[i].sub,
                            bpm: _beats[i].bpm,
                            selected: i == _beatSelected,
                            onTap: () => _previewBeat(i),
                          ),
                        ),
                ),
                GradientButton(
                  label: l10n?.chooseThisBeat ?? 'Choose this beat',
                  icon: Icons.play_arrow_rounded,
                  onPressed: _songsTab ? null : () => _choose(l10n),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        color: AppColors.card,
        shape: const CircleBorder(),
        child: InkResponse(
          onTap: () => Navigator.of(context).maybePop(),
          radius: 28,
          child: const SizedBox(
            width: A11y.minTapTarget,
            height: A11y.minTapTarget,
            child: Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

/// Segmented control: outer radius 14, inner tabs radius 11, field bg.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.songs,
    required this.onSelect,
    this.beatsLabel = 'Beats',
    this.songsLabel = 'Songs',
  });
  final bool songs;
  final ValueChanged<bool> onSelect;
  final String beatsLabel;
  final String songsLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tab(beatsLabel, !songs, () => onSelect(false)),
          _tab(songsLabel, songs, () => onSelect(true)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.ink : AppColors.inkFaint,
            ),
          ),
        ),
      ),
    );
  }
}

class _BeatTile extends StatelessWidget {
  const _BeatTile({
    required this.name,
    required this.sub,
    required this.bpm,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final String sub;
  final int bpm;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        label: '$name, $bpm beats per minute',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              constraints: const BoxConstraints(minHeight: 74),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.line,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Equalizer waveform tile
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primarySoft
                          : AppColors.surfaceSunk,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: EqualizerBars(
                        barCount: 5,
                        color: selected
                            ? AppColors.primary
                            : AppColors.inkFaint,
                        active: selected,
                        barWidth: 3.0,
                        gap: 2.5,
                        minHeight: 3,
                        maxHeight: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name,
                            style: AppType.h2.copyWith(fontSize: 18)),
                        const SizedBox(height: 2),
                        Text('$sub · $bpm bpm',
                            style: AppType.label),
                      ],
                    ),
                  ),
                  // Radio selector
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.inkFaint,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder for the not-yet-built music feature.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.library_music_outlined,
              color: AppColors.inkFaint, size: 40),
          const SizedBox(height: AppSpacing.md),
          Text('Functionality coming soon',
              style: AppType.h2.copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text('Music selection isn’t available just yet.',
              style: AppType.label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
