import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/persistence/app_prefs.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../services/medication/medication_search.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/profile_fields.dart';

/// Screen 09 — Profile. Personal, medical and emergency-contact info, backed by
/// local storage and shared field widgets so it stays in sync with onboarding.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _clinician = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();

  final _nameFocus = FocusNode();
  final _clinicianFocus = FocusNode();
  final _contactNameFocus = FocusNode();
  final _contactPhoneFocus = FocusNode();

  DateTime? _birthdate;
  List<String> _meds = [];
  String? _relationship;
  String _dialCode = '+1';
  bool _dirty = false;
  Timer? _typeTimer;

  @override
  void initState() {
    super.initState();
    AppPrefs.getProfile().then((d) {
      if (!mounted) return;
      setState(() {
        _name.text = d['name'] ?? '';
        _clinician.text = d['clinician'] ?? '';
        _contactName.text = d['contactName'] ?? '';
        _contactPhone.text = d['contactPhone'] ?? '';
        _birthdate = DateTime.tryParse(d['birthdate'] ?? '');
        _meds = MedicationSearch.decode(d['meds'] ?? '');
        _relationship =
            (d['contactType'] ?? '').isEmpty ? null : d['contactType'];
        _dialCode = (d['contactPhoneCode'] ?? '+1').isEmpty
            ? '+1'
            : d['contactPhoneCode']!;
        _dirty = false;
      });
    });
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
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
    // Propagate the name everywhere it's shown (Home, Summary, …).
    ref.invalidate(userNameProvider);
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Changes saved')),
    );
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Voice-driven live editing ───────────────────────────────────────────
  // aria pushes a [ProfileEdit]; we focus the matching field and type it in so
  // the user watches the change happen, then save it.
  void _applyVoiceEdit(ProfileEdit edit) {
    switch (edit.field) {
      case 'name':
        _typeInto(_name, _nameFocus, edit.value);
      case 'clinician':
        _typeInto(_clinician, _clinicianFocus, edit.value);
      case 'contactName':
        _typeInto(_contactName, _contactNameFocus, edit.value);
      case 'contactPhone':
        _typeInto(_contactPhone, _contactPhoneFocus, edit.value);
      case 'contactType':
        setState(() {
          _relationship = edit.value;
          _dirty = true;
        });
        _save();
      case 'meds':
        if (!_meds.contains(edit.value)) {
          setState(() {
            _meds = [..._meds, edit.value];
            _dirty = true;
          });
          _save();
        }
    }
  }

  void _typeInto(TextEditingController c, FocusNode f, String value) {
    _typeTimer?.cancel();
    f.requestFocus();
    c.text = '';
    var i = 0;
    _typeTimer = Timer.periodic(const Duration(milliseconds: 55), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (i >= value.length) {
        t.cancel();
        setState(() => _dirty = true);
        _save();
        return;
      }
      i++;
      c.text = value.substring(0, i);
      c.selection = TextSelection.collapsed(offset: c.text.length);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _name.dispose();
    _clinician.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    _nameFocus.dispose();
    _clinicianFocus.dispose();
    _contactNameFocus.dispose();
    _contactPhoneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // aria asked to change a field — live-type it, then consume the request.
    ref.listen<ProfileEdit?>(profileEditProvider, (prev, next) {
      if (next != null) {
        _applyVoiceEdit(next);
        ref.read(profileEditProvider.notifier).clear();
      }
    });

    return ListView(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg,
          AppSpacing.navClearance + MediaQuery.of(context).padding.bottom),
      children: [
        Text(l10n?.profile ?? 'Profile', style: AppType.h1),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: l10n?.personalInfo ?? 'Personal information',
          icon: Icons.person_rounded,
          children: [
            LabeledTextField(
              label: l10n?.fieldName ?? 'Name',
              controller: _name,
              focusNode: _nameFocus,
              onChanged: (_) => _markDirty(),
            ),
            BirthdateField(
              date: _birthdate,
              onChanged: (d) => setState(() {
                _birthdate = d;
                _dirty = true;
              }),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: l10n?.medicalInfo ?? 'Medical information',
          icon: Icons.local_hospital_rounded,
          children: [
            MedicationField(
              meds: _meds,
              onChanged: (m) => setState(() {
                _meds = m;
                _dirty = true;
              }),
            ),
            LabeledTextField(
              label: l10n?.fieldClinician ?? 'Assigned clinician',
              controller: _clinician,
              focusNode: _clinicianFocus,
              onChanged: (_) => _markDirty(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: l10n?.emergencyContact ?? 'Emergency contact',
          icon: Icons.phone_android_rounded,
          children: [
            RelationshipDropdown(
              value: _relationship,
              onChanged: (v) => setState(() {
                _relationship = v;
                _dirty = true;
              }),
            ),
            LabeledTextField(
              label: l10n?.fieldName ?? 'Name',
              controller: _contactName,
              focusNode: _contactNameFocus,
              onChanged: (_) => _markDirty(),
            ),
            PhoneField(
              dialCode: _dialCode,
              controller: _contactPhone,
              numberFocusNode: _contactPhoneFocus,
              onCodeChanged: (v) => setState(() {
                _dialCode = v ?? '+1';
                _dirty = true;
              }),
              onNumberChanged: (_) => _markDirty(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GradientButton(
          label: l10n?.saveChanges ?? 'Save changes',
          icon: Icons.check_rounded,
          onPressed: _dirty ? _save : null,
          gradient: AppColors.pinkGradient,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.icon});
  final String title;
  final List<Widget> children;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppType.label),
              if (icon != null)
                Icon(icon, size: 20, color: AppColors.inkFaint),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}
