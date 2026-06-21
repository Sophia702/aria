import 'package:shared_preferences/shared_preferences.dart';

/// Minimal local persistence. For now only tracks whether first-run onboarding
/// has been completed; profile/settings/session persistence comes later.
class AppPrefs {
  AppPrefs._();
  static const _kOnboarded = 'onboarded';

  static Future<bool> isOnboarded() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kOnboarded) ?? false;
  }

  static Future<void> setOnboarded() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOnboarded, true);
  }

  static const _kVoice = 'voiceEnabled';

  static Future<bool> voiceEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kVoice) ?? false;
  }

  static Future<void> setVoiceEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kVoice, value);
  }

  // ── Audio + notifications ─────────────────────────────────────────────────
  static const _kCueVolume = 'cueVolume'; // 0–100
  static const _kReminders = 'remindersEnabled';

  static Future<int> cueVolume() async =>
      (await SharedPreferences.getInstance()).getInt(_kCueVolume) ?? 80;
  static Future<void> setCueVolume(int v) async =>
      (await SharedPreferences.getInstance()).setInt(_kCueVolume, v);

  static Future<bool> remindersEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_kReminders) ?? false;
  static Future<void> setRemindersEnabled(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kReminders, v);

  static const _kName = 'profile_name';
  static const _kBirthdate = 'profile_birthdate'; // ISO yyyy-MM-dd
  static const _kMeds = 'profile_meds'; // JSON list of strings
  static const _kClinician = 'profile_clinician';
  static const _kContactType = 'profile_contactType';
  static const _kContactName = 'profile_contactName';
  static const _kContactPhoneCode = 'profile_contactPhoneCode'; // e.g. +1
  static const _kContactPhone = 'profile_contactPhone';

  static Future<String> getName() async => (await SharedPreferences.getInstance()).getString(_kName) ?? '';
  static Future<void> setName(String v) async => (await SharedPreferences.getInstance()).setString(_kName, v);
  static Future<Map<String, String>> getProfile() async {
    final p = await SharedPreferences.getInstance();
    return {
      'name': p.getString(_kName) ?? '',
      'birthdate': p.getString(_kBirthdate) ?? '',
      'meds': p.getString(_kMeds) ?? '',
      'clinician': p.getString(_kClinician) ?? '',
      'contactType': p.getString(_kContactType) ?? '',
      'contactName': p.getString(_kContactName) ?? '',
      'contactPhoneCode': p.getString(_kContactPhoneCode) ?? '+1',
      'contactPhone': p.getString(_kContactPhone) ?? '',
    };
  }
  static Future<void> saveProfile(Map<String, String> data) async {
    final p = await SharedPreferences.getInstance();
    for (final e in data.entries) {
      await p.setString('profile_${e.key}', e.value);
    }
  }
}
