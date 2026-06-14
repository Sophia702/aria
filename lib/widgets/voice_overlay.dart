import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/tokens.dart';
import '../data/persistence/app_prefs.dart';
import '../services/voice/voice_controller.dart';

/// Wraps the whole app (via MaterialApp.builder). Shows a bottom-sheet
/// conversation panel whenever voice mode is on, and auto-enables it on launch
/// if the user saved the preference.
class VoiceOverlay extends ConsumerStatefulWidget {
  const VoiceOverlay({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<VoiceOverlay> createState() => _VoiceOverlayState();
}

class _VoiceOverlayState extends ConsumerState<VoiceOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await AppPrefs.voiceEnabled()) {
        ref.read(voiceControllerProvider.notifier).enable();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(voiceControllerProvider);
    final show = v.enabled || v.status == VoiceStatus.unavailable;
    return Stack(
      children: [
        widget.child,
        if (show)
          Align(
            alignment: Alignment.bottomCenter,
            child: _ConversationPanel(state: v),
          ),
      ],
    );
  }
}

class _ConversationPanel extends ConsumerWidget {
  const _ConversationPanel({required this.state});
  final VoiceUiState state;

  String get _statusLabel => switch (state.status) {
        VoiceStatus.listening => 'Listening…',
        VoiceStatus.speaking => 'aria is speaking',
        VoiceStatus.confirming => 'Say yes or no',
        VoiceStatus.unavailable => 'Voice unavailable',
        _ => 'Tap mic to talk',
      };

  Color get _statusColor => switch (state.status) {
        VoiceStatus.listening => AppColors.connected,
        VoiceStatus.speaking => AppColors.primary,
        VoiceStatus.confirming => AppColors.cue,
        VoiceStatus.unavailable => AppColors.notConnected,
        _ => AppColors.inkFaint,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(voiceControllerProvider.notifier);
    final maxHeight = MediaQuery.of(context).size.height * 0.40;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: AppShadows.raised,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header row ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.xs, 0),
                child: Row(
                  children: [
                    // aria logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/images/aria_logo.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.record_voice_over_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'aria',
                      style: AppType.h2.copyWith(
                        fontSize: 17,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Pulsing status indicator
                    _StatusDot(status: state.status),
                    const Spacer(),
                    // Tap-to-talk fallback
                    Semantics(
                      button: true,
                      label: 'Listen now',
                      child: IconButton(
                        onPressed: controller.listenNow,
                        icon: const Icon(
                          Icons.mic_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ),
                    // Close / turn off voice
                    Semantics(
                      button: true,
                      label: 'Turn off voice',
                      child: IconButton(
                        onPressed: () async {
                          await controller.disable();
                          await AppPrefs.setVoiceEnabled(false);
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.inkFaint,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Conversation bubbles ─────────────────────────────────────
              if (state.caption.isNotEmpty || state.lastHeard.isNotEmpty)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                    reverse: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.caption.isNotEmpty)
                          _Bubble(
                            text: state.caption,
                            isAria: true,
                          ),
                        if (state.lastHeard.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          _Bubble(
                            text: state.lastHeard,
                            isAria: false,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // ── Status text ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
                child: Text(
                  _statusLabel,
                  style: AppType.label.copyWith(color: _statusColor),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsing green dot when listening, static otherwise.
class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.status});
  final VoiceStatus status;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isListening = widget.status == VoiceStatus.listening;
    final color = isListening ? AppColors.connected : AppColors.inkFaint.withValues(alpha: 0.4);

    if (isListening) {
      return AnimatedBuilder(
        animation: _scale,
        builder: (_, _) => Transform.scale(
          scale: _scale.value,
          child: _dot(color),
        ),
      );
    }
    return _dot(color);
  }

  Widget _dot(Color color) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
}

/// A single conversation bubble.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.isAria});
  final String text;
  final bool isAria;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          isAria ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: isAria ? AppColors.primarySoft : AppColors.field,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isAria ? 4 : 14),
                bottomRight: Radius.circular(isAria ? 14 : 4),
              ),
            ),
            child: Text(
              isAria ? 'aria: $text' : 'you: $text',
              style: AppType.body.copyWith(
                fontSize: 14,
                color: isAria ? AppColors.primaryDeep : AppColors.inkSoft,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
