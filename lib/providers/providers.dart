import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/walk_session.dart';
import '../data/models/walk_stats.dart';
import '../data/persistence/app_prefs.dart';
import '../data/persistence/session_store.dart';
import '../services/cue/cue_engine.dart';
import '../services/cue/metronome_cue_engine.dart';
import '../services/intervention/default_intervention_manager.dart';
import '../services/intervention/intervention_manager.dart';
import '../services/model/back_sensor_fog_model.dart';
import '../services/model/fog_model.dart';
import '../services/sensors/arduino_back_sensor_source.dart';
import '../services/sensors/arduino_ble_service.dart';
import '../services/sensors/sensor_source.dart';
import '../services/session/session_controller.dart';
import '../services/session/session_state.dart';
import '../services/voice/mock_voice_assistant.dart';
import '../services/voice/openai_voice_assistant.dart';
import '../services/voice/voice_assistant.dart';

/// Global navigator key so the voice agent can drive navigation from outside the
/// widget tree. Wired to MaterialApp.navigatorKey.
final navigatorKey = GlobalKey<NavigatorState>();

/// App locale — driven by the Settings Language toggle.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => const Locale('en');
  void set(Locale locale) => state = locale;
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

/// Set true to use the mic-free MockVoiceAssistant (e.g. on an emulator).
const bool kUseMockVoice = false;

/// Dependency wiring — the real pipeline (single back-mounted Arduino):
///   sensorSourceProvider : ArduinoBackSensorSource (wraps arduinoBleProvider)
///   fogModelProvider     : BackSensorFogModel (assets/models/fog_model_back.tflite)
///   cueEngineProvider    : MetronomeCueEngine (+ audio_service for background)
/// Swap either back to a Mock* implementation here for demos without hardware.

final sensorSourceProvider = Provider<SensorSource>((ref) {
  final s = ArduinoBackSensorSource(ref.watch(arduinoBleProvider));
  ref.onDispose(() => s.dispose());
  return s;
});

final fogModelProvider = Provider<FogModel>((ref) {
  final m = BackSensorFogModel();
  ref.onDispose(() => m.dispose());
  return m;
});

final cueEngineProvider = Provider<CueEngine>((ref) {
  final c = MetronomeCueEngine();
  ref.onDispose(() => c.dispose());
  return c;
});

final interventionManagerProvider = Provider<InterventionManager>((ref) {
  final i = DefaultInterventionManager();
  ref.onDispose(() => i.dispose());
  return i;
});

final voiceAssistantProvider = Provider<VoiceAssistant>((ref) {
  final VoiceAssistant v =
      kUseMockVoice ? MockVoiceAssistant() : OpenAiVoiceAssistant();
  ref.onDispose(() => v.dispose());
  return v;
});

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionSnapshot>(SessionController.new);

/// Active bottom-nav tab index (Home/Progress/Profile/Settings). Lifted out of
/// MainShell so the voice agent can switch tabs.
class NavIndexController extends Notifier<int> {
  @override
  int build() => 0;
  void set(int i) => state = i;
}

final navIndexProvider = NotifierProvider<NavIndexController, int>(
  NavIndexController.new,
);

class UserNameNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() => AppPrefs.getName();
  Future<void> setName(String name) async {
    await AppPrefs.setName(name);
    state = AsyncValue.data(name);
  }
}
final userNameProvider = AsyncNotifierProvider<UserNameNotifier, String>(UserNameNotifier.new);

final arduinoBleProvider = Provider<ArduinoBleService>((ref) {
  final s = ArduinoBleService();
  ref.onDispose(() => s.dispose());
  return s;
});

/// Locally-persisted history of completed walks. Single source of truth for
/// Home / Progress / Summary stats.
class SessionHistoryNotifier extends AsyncNotifier<List<WalkSession>> {
  @override
  Future<List<WalkSession>> build() => SessionStore.all();

  Future<void> record(WalkSession s) async {
    await SessionStore.add(s);
    state = AsyncData(await SessionStore.all());
  }

  Future<void> clearAll() async {
    await SessionStore.clear();
    state = const AsyncData([]);
  }
}

final sessionHistoryProvider =
    AsyncNotifierProvider<SessionHistoryNotifier, List<WalkSession>>(
        SessionHistoryNotifier.new);

/// Display-ready aggregates derived from [sessionHistoryProvider].
final walkStatsProvider = Provider<WalkStats>((ref) {
  final sessions = ref.watch(sessionHistoryProvider).asData?.value ?? const [];
  return WalkStats.from(sessions);
});

/// A voice-driven request to fill a profile field — the Profile screen listens
/// and live-types the value into the matching field so the user sees the change
/// happen in real time. `field` ∈ name/clinician/contactName/contactPhone/
/// contactType/meds.
class ProfileEdit {
  final String field;
  final String value;
  const ProfileEdit(this.field, this.value);
}

class ProfileEditNotifier extends Notifier<ProfileEdit?> {
  @override
  ProfileEdit? build() => null;
  void request(String field, String value) =>
      state = ProfileEdit(field, value);
  void clear() => state = null;
}

final profileEditProvider =
    NotifierProvider<ProfileEditNotifier, ProfileEdit?>(
        ProfileEditNotifier.new);
