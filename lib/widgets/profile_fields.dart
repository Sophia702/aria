import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/tokens.dart';
import '../services/medication/medication_search.dart';

/// Shared profile/onboarding form fields so both screens look and behave
/// identically and write the same data. See [BirthdateField],
/// [MedicationField], [RelationshipDropdown], [PhoneField], [LabeledTextField].

const _fieldFill = AppColors.field;
const _fieldRadius = 11.0;

InputDecoration _fieldDecoration({String? hint}) => InputDecoration(
      isDense: true,
      filled: true,
      hintText: hint,
      fillColor: _fieldFill,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );

/// label + child wrapper matching the existing field style.
class _FieldShell extends StatelessWidget {
  const _FieldShell({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.label.copyWith(color: AppColors.inkSoft)),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

/// Plain labelled text field (name, clinician, contact name).
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.onChanged,
    this.focusNode,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      label: label,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: AppType.h2.copyWith(fontSize: 18),
        decoration: _fieldDecoration(hint: hint),
      ),
    );
  }
}

/// Birth date picker (scrollable wheel) with an auto-calculated age chip.
class BirthdateField extends StatelessWidget {
  const BirthdateField(
      {super.key, required this.date, required this.onChanged, this.label = 'Birth date'});
  final DateTime? date;
  final String label;
  final ValueChanged<DateTime> onChanged;

  static int ageFrom(DateTime d, [DateTime? now]) {
    final n = now ?? DateTime.now();
    var age = n.year - d.year;
    if (n.month < d.month || (n.month == d.month && n.day < d.day)) age--;
    return age;
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    var temp = date ?? DateTime(now.year - 70, now.month, now.day);
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 320,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    Text('Birth date',
                        style: AppType.h2.copyWith(fontSize: 16)),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, temp),
                      child: const Text('Done',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.lineSoft),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: temp,
                  minimumDate: DateTime(now.year - 120),
                  maximumDate: now,
                  onDateTimeChanged: (d) => temp = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final text =
        date == null ? 'Select date' : DateFormat('MMMM d, yyyy').format(date!);
    final age = date == null ? null : ageFrom(date!);
    return _FieldShell(
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(_fieldRadius),
        onTap: () => _pick(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 14),
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(_fieldRadius),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 18, color: AppColors.inkFaint),
              const SizedBox(width: 10),
              Text(
                text,
                style: AppType.h2.copyWith(
                  fontSize: 18,
                  color: date == null ? AppColors.inkFaint : AppColors.ink,
                ),
              ),
              const Spacer(),
              if (age != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text('Age $age',
                      style: AppType.label.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Comprehensive emergency-contact relationship picker.
class RelationshipDropdown extends StatelessWidget {
  const RelationshipDropdown(
      {super.key, required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  static const options = <String>[
    'Spouse', 'Partner', 'Mother', 'Father', 'Daughter', 'Son',
    'Sister', 'Brother', 'Grandmother', 'Grandfather', 'Granddaughter',
    'Grandson', 'Aunt', 'Uncle', 'Niece', 'Nephew', 'Cousin',
    'Friend', 'Neighbor', 'Caregiver', 'Doctor', 'Nurse',
    'Guardian', 'In-law', 'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final current = (value != null && options.contains(value)) ? value : null;
    return _FieldShell(
      label: 'Relationship',
      child: DropdownButtonFormField<String>(
        initialValue: current,
        isExpanded: true,
        hint: Text('Select relationship',
            style: AppType.h2.copyWith(fontSize: 18, color: AppColors.inkFaint)),
        icon: const Icon(Icons.expand_more_rounded, color: AppColors.inkFaint),
        style: AppType.h2.copyWith(fontSize: 18, color: AppColors.ink),
        dropdownColor: Colors.white,
        decoration: _fieldDecoration(),
        items: [
          for (final o in options)
            DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// Country dial-code selector + phone number entry.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.dialCode,
    required this.controller,
    required this.onCodeChanged,
    this.onNumberChanged,
    this.numberFocusNode,
  });
  final String dialCode;
  final TextEditingController controller;
  final ValueChanged<String?> onCodeChanged;
  final ValueChanged<String>? onNumberChanged;
  final FocusNode? numberFocusNode;

  // (flag, dial code, name) — common destinations, US/Canada first.
  static const codes = <(String, String, String)>[
    ('🇨🇦', '+1', 'Canada / US'),
    ('🇬🇧', '+44', 'UK'),
    ('🇫🇷', '+33', 'France'),
    ('🇩🇪', '+49', 'Germany'),
    ('🇮🇪', '+353', 'Ireland'),
    ('🇦🇺', '+61', 'Australia'),
    ('🇳🇿', '+64', 'New Zealand'),
    ('🇮🇳', '+91', 'India'),
    ('🇲🇽', '+52', 'Mexico'),
    ('🇧🇷', '+55', 'Brazil'),
    ('🇪🇸', '+34', 'Spain'),
    ('🇮🇹', '+39', 'Italy'),
    ('🇳🇱', '+31', 'Netherlands'),
    ('🇵🇹', '+351', 'Portugal'),
    ('🇨🇳', '+86', 'China'),
    ('🇯🇵', '+81', 'Japan'),
    ('🇿🇦', '+27', 'South Africa'),
  ];

  @override
  Widget build(BuildContext context) {
    final current =
        codes.any((c) => c.$2 == dialCode) ? dialCode : codes.first.$2;
    return _FieldShell(
      label: 'Phone',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: _fieldFill,
              borderRadius: BorderRadius.circular(_fieldRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: current,
                icon: const Icon(Icons.expand_more_rounded,
                    color: AppColors.inkFaint),
                dropdownColor: Colors.white,
                style: AppType.h2.copyWith(fontSize: 16, color: AppColors.ink),
                items: [
                  for (final c in codes)
                    DropdownMenuItem(
                      value: c.$2,
                      child: Text('${c.$1} ${c.$2}'),
                    ),
                ],
                onChanged: onCodeChanged,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: numberFocusNode,
              keyboardType: TextInputType.phone,
              onChanged: onNumberChanged,
              style: AppType.h2.copyWith(fontSize: 18),
              decoration: _fieldDecoration(hint: 'Phone number'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Medication entry: type to search a large US/Canada drug list (RxNorm),
/// tap a suggestion to add it, repeat to add several. Added meds show as chips.
class MedicationField extends StatefulWidget {
  const MedicationField(
      {super.key, required this.meds, required this.onChanged});
  final List<String> meds;
  final ValueChanged<List<String>> onChanged;

  @override
  State<MedicationField> createState() => _MedicationFieldState();
}

class _MedicationFieldState extends State<MedicationField> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<String> _suggestions = const [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await MedicationSearch.suggest(value);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    });
  }

  void _add(String med) {
    if (!widget.meds.contains(med)) {
      widget.onChanged([...widget.meds, med]);
    }
    _q.clear();
    setState(() => _suggestions = const []);
  }

  void _remove(String med) =>
      widget.onChanged(widget.meds.where((m) => m != med).toList());

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      label: 'Medications',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.meds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in widget.meds)
                    Chip(
                      label: Text(m),
                      labelStyle: AppType.label
                          .copyWith(color: AppColors.primary, fontSize: 13),
                      backgroundColor: AppColors.primarySoft,
                      side: BorderSide.none,
                      deleteIconColor: AppColors.primary,
                      onDeleted: () => _remove(m),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ),
          TextField(
            controller: _q,
            onChanged: _onQuery,
            onSubmitted: (v) {
              final t = v.trim();
              if (t.isNotEmpty) _add(t);
            },
            style: AppType.h2.copyWith(fontSize: 18),
            decoration: _fieldDecoration(hint: 'Type to search…').copyWith(
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : const Icon(Icons.search_rounded,
                      color: AppColors.inkFaint),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_fieldRadius),
                border: Border.all(color: AppColors.line),
              ),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final s in _suggestions)
                    InkWell(
                      onTap: () => _add(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.add_circle_outline,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(s,
                                    style: AppType.body
                                        .copyWith(fontSize: 15))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
