import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/a11y/a11y.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../providers/providers.dart';
import '../../widgets/gradient_button.dart';
import 'walking_screen.dart';

/// Screen 11 — Choose your beat. Shown before a walk: pick a metronome tempo
/// (Songs is a later, music-integration tab). "Choose this beat" starts the
/// session at the selected cadence and opens the Walking screen.
class ChooseBeatScreen extends ConsumerStatefulWidget {
  const ChooseBeatScreen({super.key});

  @override
  ConsumerState<ChooseBeatScreen> createState() => _ChooseBeatScreenState();
}

class _ChooseBeatScreenState extends ConsumerState<ChooseBeatScreen> {
  static const _beats = [
    (name: 'Steady click', desc: 'Calm and even', bpm: 90),
    (name: 'Gentle pulse', desc: 'Easy walking pace', bpm: 100),
    (name: 'Bright tick', desc: 'A little brisker', bpm: 110),
    (name: 'Walking march', desc: 'Strong, marching beat', bpm: 120),
  ];

  int _selected = 1;
  bool _songsTab = false;

  Future<void> _choose() async {
    final bpm = _beats[_selected].bpm.toDouble();
    await ref.read(sessionControllerProvider.notifier).startSession(bpm: bpm);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WalkingScreen()),
    );
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
                Row(
                  children: [
                    _BackButton(),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Choose your beat', style: AppType.h2),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _Tabs(
                  songs: _songsTab,
                  onSelect: (s) => setState(() => _songsTab = s),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: _songsTab
                      ? const _SongsPlaceholder()
                      : ListView.builder(
                          itemCount: _beats.length,
                          itemBuilder: (context, i) => _BeatTile(
                            name: _beats[i].name,
                            desc: _beats[i].desc,
                            bpm: _beats[i].bpm,
                            selected: i == _selected,
                            onTap: () => setState(() => _selected = i),
                          ),
                        ),
                ),
                if (!_songsTab)
                  GradientButton(
                    label: 'Choose this beat',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _choose,
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

class _Tabs extends StatelessWidget {
  const _Tabs({required this.songs, required this.onSelect});
  final bool songs;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          _tab('Beats', !songs, () => onSelect(false)),
          _tab('Songs', songs, () => onSelect(true)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            boxShadow: active ? AppShadows.card : null,
          ),
          child: Text(label,
              style: AppType.label.copyWith(
                  color: active ? AppColors.ink : AppColors.label, fontSize: 15)),
        ),
      ),
    );
  }
}

class _BeatTile extends StatelessWidget {
  const _BeatTile({
    required this.name,
    required this.desc,
    required this.bpm,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final String desc;
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
            child: Container(
              constraints: const BoxConstraints(minHeight: 74),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                boxShadow: AppShadows.card,
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.music_note, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name, style: AppType.h2.copyWith(fontSize: 18)),
                        Text('$desc · $bpm bpm', style: AppType.label),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? AppColors.primary : AppColors.label,
                    size: 26,
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

class _SongsPlaceholder extends StatelessWidget {
  const _SongsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.library_music_outlined,
              color: AppColors.label, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text('Tempo-matched songs', style: AppType.h2.copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text('Music integration is coming soon.', style: AppType.body),
        ],
      ),
    );
  }
}
