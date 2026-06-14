import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/session/summary_screen.dart';
import '../../features/session/walking_screen.dart';
import '../../providers/providers.dart';
import '../../data/persistence/app_prefs.dart';
import '../intervention/intervention_manager.dart';
import '../session/session_state.dart';
import 'claude_api_service.dart';

enum VoiceStatus { off, idle, listening, speaking, confirming, unavailable }

/// What the overlay renders.
class VoiceUiState {
  final bool enabled;
  final VoiceStatus status;
  final String caption; // what aria last said / is prompting
  final String lastHeard; // what the user last said

  const VoiceUiState({
    this.enabled = false,
    this.status = VoiceStatus.off,
    this.caption = '',
    this.lastHeard = '',
  });

  VoiceUiState copyWith({
    bool? enabled,
    VoiceStatus? status,
    String? caption,
    String? lastHeard,
  }) =>
      VoiceUiState(
        enabled: enabled ?? this.enabled,
        status: status ?? this.status,
        caption: caption ?? this.caption,
        lastHeard: lastHeard ?? this.lastHeard,
      );
}

/// Pending phone call awaiting a spoken yes/no confirmation.
enum _PendingCall { emergency }

/// Orchestrates the hands-free loop: greet → listen → send to Claude →
/// act on tool calls or speak responses → repeat. Drives navigation via
/// [navigatorKey] + [navIndexProvider] and the walk via the session controller.
class VoiceController extends Notifier<VoiceUiState> {
  final _claude = ClaudeApiService();
  final List<ClaudeMessage> _history = [];
  bool _looping = false;
  _PendingCall? _pending;

  @override
  VoiceUiState build() => const VoiceUiState();

  Future<void> enable() async {
    if (state.enabled) return;
    state = state.copyWith(enabled: true, status: VoiceStatus.idle);
    final assistant = ref.read(voiceAssistantProvider);
    final ok = await assistant.init();
    if (!ok) {
      state = state.copyWith(
        status: VoiceStatus.unavailable,
        caption: 'Voice needs a microphone — try on a real device.',
      );
      return;
    }
    await _say("Hi, I'm aria. How can I help you today?");
    _loop();
  }

  Future<void> disable() async {
    state = state.copyWith(
        enabled: false, status: VoiceStatus.off, caption: '', lastHeard: '');
    _pending = null;
    _history.clear();
    await ref.read(voiceAssistantProvider).stopListening();
  }

  /// Tap-to-talk fallback: ensure the listen loop is running.
  void listenNow() {
    if (state.enabled && !_looping) _loop();
  }

  Future<void> _say(String text) async {
    state = state.copyWith(status: VoiceStatus.speaking, caption: text);
    await ref.read(voiceAssistantProvider).speak(text);
  }

  Future<void> _loop() async {
    if (_looping) return;
    _looping = true;
    final assistant = ref.read(voiceAssistantProvider);
    while (state.enabled) {
      state = state.copyWith(
          status: _pending != null
              ? VoiceStatus.confirming
              : VoiceStatus.listening);
      final text = await assistant.listenOnce();
      if (!state.enabled) break;
      if (text == null || text.trim().isEmpty) continue;
      state = state.copyWith(lastHeard: text);

      // If there is a pending call confirmation, handle it with simple keyword
      // matching before going to Claude (avoids extra API latency for yes/no).
      if (_pending != null) {
        await _resolvePending(text);
        continue;
      }

      // Send to Claude.
      final response = await _claude.chat(text, _history);

      if (response is ClaudeTextResponse) {
        _history.addAll(response.updatedHistory.skip(_history.length));
        await _say(response.text);
      } else if (response is ClaudeToolResponse) {
        // Update history with user turn + assistant tool_use turn.
        _history.addAll(response.updatedHistory.skip(_history.length));

        final toolResult = await _handleToolCall(response);

        // Send tool result back to Claude for a spoken confirmation.
        final confirmationText = await _claude.sendToolResult(
          response.toolUseId,
          toolResult,
          response.updatedHistory,
        );

        // Append tool_result user turn + assistant confirmation turn to history.
        _history.add(ClaudeMessage(
          role: 'user',
          content: [
            {
              'type': 'tool_result',
              'tool_use_id': response.toolUseId,
              'content': toolResult,
            },
          ],
        ));
        _history.add(ClaudeMessage(role: 'assistant', content: confirmationText));

        await _say(confirmationText);
      } else if (response is ClaudeErrorResponse) {
        await _say("Sorry, I had a problem understanding that. Please try again.");
      }
    }
    _looping = false;
  }

  /// Handle a pending call confirmation with simple yes/no keyword detection.
  Future<void> _resolvePending(String text) async {
    final lower = text.toLowerCase();
    final isYes = lower.contains('yes') || lower.contains('yeah') || lower.contains('sure');
    final isNo = lower.contains('no') || lower.contains('nope') || lower.contains('cancel');

    if (isYes) {
      final p = _pending!;
      _pending = null;
      await _dial(p);
    } else if (isNo) {
      _pending = null;
      await _say('Okay, cancelled.');
    } else {
      await _say('Please say yes or no.');
    }
  }

  Future<String> _handleToolCall(ClaudeToolResponse r) async {
    switch (r.toolName) {
      case 'navigate_to':
        final screen = r.toolInput['screen'] as String? ?? '';
        final screenIndex = r.toolInput['screenIndex'] as int? ?? 0;
        _goTab(screenIndex, screen);
        return 'Navigated to ${r.toolInput['screen']}';

      case 'start_walk':
        await _startWalk();
        return 'Walk started';

      case 'end_walk':
        await _endWalk();
        return 'Walk ended';

      case 'update_setting':
        final setting = r.toolInput['setting'] as String? ?? '';
        final value = r.toolInput['value'] as String? ?? '';
        await _updateSetting(setting, value);
        return 'Setting updated';

      case 'update_profile':
        final field = r.toolInput['field'] as String? ?? '';
        final value = r.toolInput['value'] as String? ?? '';
        await AppPrefs.saveProfile({field: value});
        if (field == 'name') {
          ref.invalidate(userNameProvider);
        }
        return 'Profile updated';

      case 'call_emergency':
        await _dial(_PendingCall.emergency);
        return 'Calling emergency contact';

      default:
        return 'Action not available';
    }
  }

  Future<void> _updateSetting(String setting, String value) async {
    switch (setting) {
      case 'voice':
        final enabled = value.toLowerCase() == 'true';
        await AppPrefs.setVoiceEnabled(enabled);
        if (!enabled) await disable();
      case 'language':
        ref.read(localeProvider.notifier).set(Locale(value));
      case 'reminders':
        // Reminders toggle — stored for future use.
        break;
    }
  }

  void _goTab(int index, String name) {
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    ref.read(navIndexProvider.notifier).set(index);
  }

  Future<void> _startWalk() async {
    final session = ref.read(sessionControllerProvider);
    if (session.state == SessionState.walkingNormal ||
        session.state == SessionState.intervention) {
      return; // Claude will handle the spoken response
    }
    await ref.read(sessionControllerProvider.notifier).startSession(bpm: 108);
    navigatorKey.currentState
        ?.push(MaterialPageRoute(builder: (_) => const WalkingScreen()));
  }

  Future<void> _endWalk() async {
    final session = ref.read(sessionControllerProvider);
    if (session.state != SessionState.walkingNormal &&
        session.state != SessionState.intervention) {
      return; // Claude will handle the spoken response
    }
    await ref.read(sessionControllerProvider.notifier).endSession();
    navigatorKey.currentState
        ?.pushReplacement(MaterialPageRoute(builder: (_) => const SummaryScreen()));
  }

  Future<void> _dial(_PendingCall which) async {
    final number = '911';
    final action = InterventionAction.callEmergencyContact;
    final session = ref.read(sessionControllerProvider);
    if (session.state == SessionState.intervention) {
      await ref
          .read(sessionControllerProvider.notifier)
          .resolveIntervention(action);
      navigatorKey.currentState?.maybePop();
    }
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
    await _say('Calling now.');
  }
}

final voiceControllerProvider =
    NotifierProvider<VoiceController, VoiceUiState>(VoiceController.new);
