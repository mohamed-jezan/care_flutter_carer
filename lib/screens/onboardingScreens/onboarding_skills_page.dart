// lib/screen/onboarding/OnboardingSkillsPage.dart

import 'package:call_care/service/onboarding_bank_details_service.dart';
import 'package:call_care/widgets/three_dot_loader.dart';
import 'package:flutter/material.dart';
import '../../model/carer_skill.dart';
import '../../model/carer_language.dart';
import '../../model/carer_availability.dart';
import '../../model/onboarding_info.dart';
import '../../service/onboarding_skills_service.dart';
import '../../service/onboarding_info_service.dart';
import '../loginScreens/signin_page.dart';

class OnboardingSkillsPage extends StatefulWidget {
  final String token;
  final String userId;
  final String username;
  final String email;
  final PageController? controller;
  final VoidCallback? onSkillsSaved;

  const OnboardingSkillsPage({
    super.key,
    required this.token,
    required this.userId,
    required this.username,
    required this.email,
    this.controller,
    this.onSkillsSaved,
  });

  @override
  _OnboardingSkillsPageState createState() => _OnboardingSkillsPageState();
}

class _OnboardingSkillsPageState extends State<OnboardingSkillsPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final OnboardingSkillsService _service;

  // ── UI: Skills ─────────────────────────────────────────────────────────────
  final Map<String, bool> _skills = {
    'personal_care': false,
    'housekeeping': false,
    'medication_support': false,
    'meal_prep_feeding': false,
    'mobility_support': false,
    'companionship': false,
    'overnight_care': false,
    'live_in_care': false,
    'dementia_support': false,
    'palliative_care': false,
    'hospital_discharge_care': false,
  };

  // Backend key -> UI label
final Map<String, String> _skillLabels = {
  'personal_care': 'Personal Care',
  'housekeeping': 'Housekeeping',
  'medication_support': 'Medication Support',
  'meal_prep_feeding': 'Meal Prep & Feeding',
  'mobility_support': 'Mobility Support',
  'companionship': 'Companionship',
  'overnight_care': 'Overnight Care',
  'live_in_care': 'Live In Care',
  'dementia_support': 'Dementia Support',
  'palliative_care': 'Palliative Care',
  'hospital_discharge_care': 'Hospital Discharge Care',
};

  // ── UI: Languages ──────────────────────────────────────────────────────────
  final _primaryLanguageController = TextEditingController();
  final _otherLanguagesController = TextEditingController();

  // ── UI: Preferences ────────────────────────────────────────────────────────
  final _preferredClientGenderController = TextEditingController();
  String? _partTimePreference;

  // ── UI: Availability ───────────────────────────────────────────────────────
  // day_of_week: 0=Sunday … 6=Saturday (matches backend INTEGER 0-6)
  static const Map<String, int> _dayNameToInt = {
    'Monday': 1,
    'Tuesday': 2,
    'Wednesday': 3,
    'Thursday': 4,
    'Friday': 5,
    'Saturday': 6,
    'Sunday': 0,
  };
  static const Map<int, String> _dayIntToName = {
    0: 'Sunday',
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
  };

  final Map<String, bool> _selectedDays = {
    'Monday': false,
    'Tuesday': false,
    'Wednesday': false,
    'Thursday': false,
    'Friday': false,
    'Saturday': false,
    'Sunday': false,
  };

  // Time slots per day: day name -> { 'start': 'HH:mm', 'end': 'HH:mm' }
  final Map<String, Map<String, String?>> _dayTimeSlots = {
    'Monday': {'start': null, 'end': null},
    'Tuesday': {'start': null, 'end': null},
    'Wednesday': {'start': null, 'end': null},
    'Thursday': {'start': null, 'end': null},
    'Friday': {'start': null, 'end': null},
    'Saturday': {'start': null, 'end': null},
    'Sunday': {'start': null, 'end': null},
  };

  static const List<String> _timeOptions = [
    '06:00', '07:00', '08:00', '09:00', '10:00', '11:00',
    '12:00', '13:00', '14:00', '15:00', '16:00', '17:00',
    '18:00', '19:00', '20:00', '21:00', '22:00', '23:00',
  ];

  // ── Existing record tracking ───────────────────────────────────────────────
  List<CarerSkill> _existingSkillRows = [];
  List<CarerLanguage> _existingLanguageRows = [];
  String? _existingPreferenceId;
  List<CarerAvailability> _existingAvailabilityRows = [];

  // ── Reference language data ────────────────────────────────────────────────
  List<Map<String, String>> _availableLanguages = [];
  Map<String, String> _langIdToName = {};
  Map<String, int> _langNameToId = {};

  // ── Per-section saved flags ────────────────────────────────────────────────
  bool _isSkillsSaved = false;
  bool _isLanguagesSaved = false;
  bool _isPreferencesSaved = false;
  bool _isAvailabilitySaved = false;

  // ── Per-section loading flags ──────────────────────────────────────────────
  bool _isPageLoading = false;
  bool _isSkillsLoading = false;
  bool _isLanguagesLoading = false;
  bool _isPreferencesLoading = false;
  bool _isAvailabilityLoading = false;

  late AnimationController _animationController;
  late Animation<double> fadeAnimation;

  static const List<String> _genders = ['Male', 'Female', 'Any'];
  static const List<String> _partTimeOptions = ['Full Time', 'Part Time'];

  // ─────────────────────────────────────────────────────────────────────────
  // Time comparison helper
  // 'HH:mm' strings are zero-padded so compareTo gives correct ordering.
  // Using compareTo instead of >= / > avoids the "operator not defined" error.
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true when [a] is at or after [b]  (a >= b)
  bool _timeNotBefore(String a, String b) => a.compareTo(b) >= 0;

  /// Returns true when [a] is strictly after [b]  (a > b)
  bool _timeAfter(String a, String b) => a.compareTo(b) > 0;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _service = OnboardingSkillsService(widget.token);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchAll();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _primaryLanguageController.dispose();
    _otherLanguagesController.dispose();
    _preferredClientGenderController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Fetch
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _fetchAll() async {
    setState(() => _isPageLoading = true);
    try {
      // 1. Reference languages
      _availableLanguages = await _service.getAllLanguages();
      _langIdToName = {
        for (final l in _availableLanguages) l['id']!: l['langEN']!
      };
      _langNameToId = {
        for (final l in _availableLanguages)
          l['langEN']!: int.tryParse(l['id']!) ?? 0
      };

      // 2. Existing skills
      final skillsResult =
          await _service.checkCarerSkillsByUserId(widget.userId);
      if (skillsResult.exists && skillsResult.rows.isNotEmpty) {
        _existingSkillRows = skillsResult.rows;
        for (final row in _existingSkillRows) {
          if (_skills.containsKey(row.skill)) _skills[row.skill] = true;
        }
        _isSkillsSaved = true;
      }

      // 3. Existing languages
      final langResult =
          await _service.checkCarerLanguagesByUserId(widget.userId);
      if (langResult.exists && langResult.rows.isNotEmpty) {
        _existingLanguageRows = langResult.rows;
        final otherNames = <String>[];
        for (final row in langResult.rows) {
          final name = _langIdToName[row.languageId.toString()] ??
              row.languageId.toString();
          if (row.isPrimary) {
            _primaryLanguageController.text = name;
          } else {
            otherNames.add(name);
          }
        }
        _otherLanguagesController.text = otherNames.join(', ');
        _isLanguagesSaved = true;
      }

      // 4. Existing preferences
      final prefResult =
          await _service.checkCarerPreferenceByUserId(widget.userId);
      if (prefResult.exists && prefResult.preference != null) {
        final pref = prefResult.preference!;
        _existingPreferenceId = pref.id;
        _preferredClientGenderController.text = pref.preferredClientGender;
        _partTimePreference =
            pref.partTimePreference == 'part-time' ? 'Part Time' : 'Full Time';
        _isPreferencesSaved = true;
      }

      // 5. Existing availability
      final availResult =
          await _service.checkCarerAvailabilityByUserId(widget.userId);
      if (availResult.exists && availResult.rows.isNotEmpty) {
        _existingAvailabilityRows = availResult.rows;
        for (final row in _existingAvailabilityRows) {
          if (row.availabilityType == 'recurring' && row.dayOfWeek != null) {
            final dayName = _dayIntToName[row.dayOfWeek!];
            if (dayName != null && _selectedDays.containsKey(dayName)) {
              _selectedDays[dayName] = true;
              _dayTimeSlots[dayName] = {
                'start': _trimSeconds(row.startTime),
                'end': _trimSeconds(row.endTime),
              };
            }
          }
        }
        _isAvailabilitySaved = true;
      }

      if (_isSkillsSaved ||
          _isLanguagesSaved ||
          _isPreferencesSaved ||
          _isAvailabilitySaved) {
        _animationController.forward();
      }
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isPageLoading = false);
    }
  }

  /// Backend stores TIME as 'HH:mm:ss' — trim to 'HH:mm' for UI dropdowns.
  String _trimSeconds(String time) =>
      time.length > 5 ? time.substring(0, 5) : time;

  // ─────────────────────────────────────────────────────────────────────────
  // Section saves
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _saveSkills() async {
    final selected =
        _skills.entries.where((e) => e.value).map((e) => e.key).toList();
    if (selected.isEmpty) {
      _showSnack('Select at least one skill');
      return;
    }
    setState(() => _isSkillsLoading = true);
    try {
      await _service.saveSkills(
        userId: widget.userId,
        skillNames: selected,
        createdBy: widget.username,
        existingRows: _existingSkillRows,
      );
      final refreshed =
          await _service.checkCarerSkillsByUserId(widget.userId);
      setState(() {
        _existingSkillRows = refreshed.rows;
        _isSkillsSaved = true;
      });
      _animationController.forward();
      widget.onSkillsSaved?.call();
      _showSnack('Skills saved successfully');
      _tryStripeAndNavigate();
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isSkillsLoading = false);
    }
  }

  Future<void> _saveLanguages() async {
    if (_primaryLanguageController.text.trim().isEmpty) {
      _showSnack('Primary language is required');
      return;
    }
    final primaryId =
        _langNameToId[_primaryLanguageController.text.trim()] ?? 0;
    if (primaryId == 0) {
      _showSnack('Please select a valid primary language from the list');
      return;
    }
    final otherIds = _otherLanguagesController.text.trim().isEmpty
        ? <int>[]
        : _otherLanguagesController.text
            .split(', ')
            .map((n) => _langNameToId[n.trim()] ?? 0)
            .where((id) => id > 0)
            .toList();

    setState(() => _isLanguagesLoading = true);
    try {
      await _service.saveLanguages(
        userId: widget.userId,
        primaryLanguageId: primaryId,
        otherLanguageIds: otherIds,
        createdBy: widget.username,
        existingRows: _existingLanguageRows,
      );
      final refreshed =
          await _service.checkCarerLanguagesByUserId(widget.userId);
      setState(() {
        _existingLanguageRows = refreshed.rows;
        _isLanguagesSaved = true;
      });
      _animationController.forward();
      widget.onSkillsSaved?.call();
      _showSnack('Languages saved successfully');
      _tryStripeAndNavigate();
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isLanguagesLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    if (_preferredClientGenderController.text.trim().isEmpty) {
      _showSnack('Preferred client gender is required');
      return;
    }
    if (_partTimePreference == null) {
      _showSnack('Work preference is required');
      return;
    }
    final ptpBackend =
        _partTimePreference == 'Part Time' ? 'part-time' : 'full-time';

    setState(() => _isPreferencesLoading = true);
    try {
      final savedId = await _service.savePreference(
        userId: widget.userId,
        existingPreferenceId: _existingPreferenceId,
        preferredClientGender: _preferredClientGenderController.text.trim(),
        partTimePreference: ptpBackend,
        createdOrUpdatedBy: widget.username,
      );
      setState(() {
        _existingPreferenceId = savedId;
        _isPreferencesSaved = true;
      });
      _animationController.forward();
      widget.onSkillsSaved?.call();
      _showSnack('Preferences saved successfully');
      _tryStripeAndNavigate();
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isPreferencesLoading = false);
    }
  }

  Future<void> _saveAvailability() async {
    final selectedDays =
        _selectedDays.entries.where((e) => e.value).toList();
    if (selectedDays.isEmpty) {
      _showSnack('Select at least one day');
      return;
    }

    // Validate time slots using compareTo — fixes the compile error
    for (final entry in selectedDays) {
      final slots = _dayTimeSlots[entry.key]!;
      final start = slots['start'];
      final end = slots['end'];
      if (start == null || end == null) {
        _showSnack('Select start and end time for ${entry.key}');
        return;
      }
      // start >= end is invalid — using compareTo instead of >=
      if (_timeNotBefore(start, end)) {
        _showSnack('Start time must be before end time for ${entry.key}');
        return;
      }
    }

    final slots = selectedDays.map((entry) {
      final dayName = entry.key;
      final dayInt = _dayNameToInt[dayName]!;
      final times = _dayTimeSlots[dayName]!;
      return CarerAvailability(
        id: '',
        userId: widget.userId,
        availabilityType: 'recurring',
        dayOfWeek: dayInt,
        startTime: times['start']!,
        endTime: times['end']!,
        isAvailable: true,
        status: 'pending',
        createdBy: widget.username,
      );
    }).toList();

    setState(() => _isAvailabilityLoading = true);
    try {
      await _service.saveAvailability(
        userId: widget.userId,
        slots: slots,
        createdBy: widget.username,
        existingRows: _existingAvailabilityRows,
      );
      final refreshed =
          await _service.checkCarerAvailabilityByUserId(widget.userId);
      setState(() {
        _existingAvailabilityRows = refreshed.rows;
        _isAvailabilitySaved = true;
      });
      _animationController.forward();
      widget.onSkillsSaved?.call();
      _showSnack('Availability saved successfully');
      _tryStripeAndNavigate();
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isAvailabilityLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stripe + navigate — only after ALL four sections are saved
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _tryStripeAndNavigate() async {
    if (!_isSkillsSaved ||
        !_isLanguagesSaved ||
        !_isPreferencesSaved ||
        !_isAvailabilitySaved) {
      return;
    }

    try {
      String userEmail = widget.email;
      if (userEmail.isEmpty) {
        final infoResult = await OnboardingInfoService(widget.token)
            .checkOnboardingInfoByUserId(widget.userId);
        if (infoResult['exists'] == true && infoResult['data'] != null) {
          final info = OnboardingInfo.fromJson(infoResult['data']);
          userEmail = info.email ?? '';
        }
      }

      if (userEmail.isEmpty) {
        _showSnack('User email not found. Cannot connect to Stripe.');
      } else {
        await OnboardingBankDetailsService(widget.token).createExpressAccount(
          userId: widget.userId,
          email: userEmail,
          createdBy: widget.username,
        );
      }

      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 200));

      if (widget.controller != null) {
        widget.controller!.animateToPage(4,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut);
      } else {
        widget.onSkillsSaved?.call();
      }
    } catch (stripeError) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'All sections saved, but Stripe setup failed: $stripeError'),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
            label: 'Retry', onPressed: _tryStripeAndNavigate),
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _showSnack(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: backgroundColor));
  }

  void _handleError(Object e) {
    if (!mounted) return;
    if (e.toString().contains('Unauthorized')) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const SignInPage()));
      _showSnack('Session expired, please log in again');
    } else {
      _showSnack('Error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white54, Colors.white10],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _isPageLoading
              ? const Center(
                  child: ThreeDotLoader(
                      color: Color(0xFFFF6F6F)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // ── Section 1: Skills ─────────────────────────────
                        _buildSectionCard(
                          title: 'Skills',
                          icon: Icons.medical_services_outlined,
                          isSaved: _isSkillsSaved,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCheckboxGroup(
                                _skills.keys.toList(),
                                _skills,
                                (u) => setState(() => _skills.addAll(u)),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: _buildSectionButton(
                                  label: _isSkillsSaved
                                      ? 'Update Skills'
                                      : 'Save Skills',
                                  isLoading: _isSkillsLoading,
                                  onPressed: _saveSkills,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Section 2: Languages ──────────────────────────
                        _buildSectionCard(
                          title: 'Languages',
                          icon: Icons.language,
                          isSaved: _isLanguagesSaved,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSearchableDropdownField(
                                controller: _primaryLanguageController,
                                label: 'Primary Language',
                                icon: Icons.language,
                                items: _availableLanguages
                                    .map((l) => l['langEN']!)
                                    .toList(),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                              _buildSearchableMultiSelectField(
                                controller: _otherLanguagesController,
                                label: 'Other Languages',
                                icon: Icons.translate,
                                items: _availableLanguages
                                    .map((l) => l['langEN']!)
                                    .toList(),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: _buildSectionButton(
                                  label: _isLanguagesSaved
                                      ? 'Update Languages'
                                      : 'Save Languages',
                                  isLoading: _isLanguagesLoading,
                                  onPressed: _saveLanguages,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Section 3: Preferences ────────────────────────
                        _buildSectionCard(
                          title: 'Preferences',
                          icon: Icons.tune,
                          isSaved: _isPreferencesSaved,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDropdownField(
                                controller: _preferredClientGenderController,
                                label: 'Preferred Client Gender',
                                icon: Icons.person,
                                items: _genders,
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Required'
                                    : null,
                                onChanged: (v) => setState(() =>
                                    _preferredClientGenderController.text =
                                        v ?? ''),
                              ),
                              _buildDropdownField(
                                controller: TextEditingController(
                                    text: _partTimePreference),
                                label: 'Work Preference',
                                icon: Icons.work,
                                items: _partTimeOptions,
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Required'
                                    : null,
                                onChanged: (v) =>
                                    setState(() => _partTimePreference = v),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: _buildSectionButton(
                                  label: _isPreferencesSaved
                                      ? 'Update Preferences'
                                      : 'Save Preferences',
                                  isLoading: _isPreferencesLoading,
                                  onPressed: _savePreferences,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Section 4: Availability ───────────────────────
                        _buildSectionCard(
                          title: 'Availability',
                          icon: Icons.calendar_month_outlined,
                          isSaved: _isAvailabilitySaved,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select your available days and working hours',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.black54),
                              ),
                              const SizedBox(height: 12),
                              _buildAvailabilityPicker(),
                              const SizedBox(height: 16),
                              Center(
                                child: _buildSectionButton(
                                  label: _isAvailabilitySaved
                                      ? 'Update Availability'
                                      : 'Save Availability',
                                  isLoading: _isAvailabilityLoading,
                                  onPressed: _saveAvailability,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Continue — only when all four are saved ────────
                        if (_isSkillsSaved &&
                            _isLanguagesSaved &&
                            _isPreferencesSaved &&
                            _isAvailabilitySaved)
                          _buildSectionButton(
                            label: 'Continue to Bank Details',
                            isLoading: false,
                            onPressed: _tryStripeAndNavigate,
                            fullWidth: true,
                          ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Availability picker
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAvailabilityPicker() {
    return Column(
      children: _selectedDays.keys.map((day) {
        final isSelected = _selectedDays[day] ?? false;
        final slots = _dayTimeSlots[day]!;
        final startVal = slots['start'];

        // End-time options: only times strictly after the selected start.
        // Uses compareTo instead of > to avoid the compile error.
        final endItems = startVal != null
            ? _timeOptions
                .where((t) => _timeAfter(t, startVal))
                .toList()
            : _timeOptions;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFF6F6F).withOpacity(0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFF6F6F).withOpacity(0.4)
                  : Colors.grey.shade200,
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              // Day checkbox row
              CheckboxListTile(
                title: Text(
                  day,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFFFF6F6F)
                        : Colors.black87,
                  ),
                ),
                value: isSelected,
                activeColor: const Color(0xFFFF6F6F),
                checkColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                onChanged: (v) => setState(() {
                  _selectedDays[day] = v ?? false;
                  if (v == false) {
                    _dayTimeSlots[day] = {'start': null, 'end': null};
                  }
                }),
              ),

              // Time pickers — only when day is ticked
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      // Start time dropdown
                      Expanded(
                        child: _buildTimeDropdown(
                          label: 'Start',
                          value: slots['start'],
                          items: _timeOptions,
                          onChanged: (v) => setState(() {
                            _dayTimeSlots[day]!['start'] = v;
                            // Reset end if it's no longer after new start
                            final currentEnd = _dayTimeSlots[day]!['end'];
                            if (v != null &&
                                currentEnd != null &&
                                !_timeAfter(currentEnd, v)) {
                              _dayTimeSlots[day]!['end'] = null;
                            }
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 10),
                      // End time dropdown — filtered to valid options
                      Expanded(
                        child: _buildTimeDropdown(
                          label: 'End',
                          value: slots['end'],
                          items: endItems,
                          onChanged: (v) =>
                              setState(() => _dayTimeSlots[day]!['end'] = v),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Guard: if current value is no longer in the filtered items list, reset
    final safeValue = (value != null && items.contains(value)) ? value : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFFFF6F6F), width: 1.5)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items
          .map((t) => DropdownMenuItem(
                value: t,
                child: Text(t,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black87)),
              ))
          .toList(),
      onChanged: onChanged,
      style: const TextStyle(color: Colors.black87, fontSize: 13),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required bool isSaved,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
        border: Border.all(
          color: isSaved
              ? const Color(0xFFFF6F6F).withOpacity(0.5)
              : Colors.grey.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6F6F).withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFFFF6F6F), size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isSaved
                        ? const Color(0xFFFF6F6F)
                        : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (isSaved)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green, size: 13),
                        SizedBox(width: 4),
                        Text('Saved',
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _buildSectionButton({
  required String label,
  required bool isLoading,
  required VoidCallback onPressed,
  bool fullWidth = false,
}) {
  return SizedBox(
    width: fullWidth ? double.infinity : null,
    child: ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: fullWidth ? 0 : 16,
          vertical: 6,
        ),
        minimumSize: Size(
          fullWidth ? double.infinity : 88,
          48,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 5,
        shadowColor: Colors.black26,
      ),
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFF6F6F),
              Color(0xFFFFA6A6),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.all(
            Radius.circular(30),
          ),
        ),
        child: Container(
          alignment: Alignment.center,
          height: 48,
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 60,
                  height: 24,
                  child: ThreeDotLoader(
                    color: Colors.white,
                  ),
                )
              : FittedBox(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
        ),
      ),
    ),
  );
}

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFFFF6F6F)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFFF6F6F), width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      labelStyle: const TextStyle(color: Colors.grey),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  Widget _buildSearchableDropdownField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<String> items,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Autocomplete<String>(
        optionsBuilder: (tv) {
          if (tv.text.isEmpty) return items;
          return items
              .where((i) => i.toLowerCase().contains(tv.text.toLowerCase()));
        },
        onSelected: (s) => setState(() => controller.text = s),
        fieldViewBuilder: (ctx, tec, fn, _) {
          if (tec.text != controller.text) tec.text = controller.text;
          return TextFormField(
            controller: tec,
            focusNode: fn,
            decoration: _inputDecoration(label, icon),
            style: const TextStyle(color: Colors.black87),
            validator: validator,
            onChanged: (v) => controller.text = v,
          );
        },
      ),
    );
  }

  Widget _buildSearchableMultiSelectField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  required List<String> items,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16.0),
    child: TextFormField(
      controller: controller,
      readOnly: true,
      decoration: _inputDecoration(label, icon),
      style: const TextStyle(color: Colors.black87),
      onTap: () async {
        final initial = controller.text.isEmpty
            ? <String>{}
            : controller.text
                .split(', ')
                .map((s) => s.trim())
                .toSet();

        final selected = await showDialog<Set<String>>(
          context: context,
          builder: (context) {
            final temp = initial.toSet();
            String filter = '';

            return StatefulBuilder(
              builder: (ctx, setS) {
                final filteredItems = items
                    .where((i) =>
                        filter.isEmpty ||
                        i.toLowerCase().contains(
                          filter.toLowerCase(),
                        ))
                    .toList();

                return Dialog(
                  insetPadding: const EdgeInsets.all(16),
                  child: SafeArea(
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight:
                            MediaQuery.of(ctx).size.height * 0.7,
                        maxWidth:
                            MediaQuery.of(ctx).size.width * 0.9,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search languages...',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (v) {
                              setS(() {
                                filter = v;
                              });
                            },
                          ),

                          const SizedBox(height: 12),

                          Expanded(
                            child: ListView(
                              children: filteredItems.map((item) {
                                return CheckboxListTile(
                                  title: Text(item),
                                  value: temp.contains(item),
                                  onChanged: (v) {
                                    setS(() {
                                      if (v == true) {
                                        temp.add(item);
                                      } else {
                                        temp.remove(item);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),

                          const SizedBox(height: 8),

                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () {
                                Navigator.pop(ctx, temp);
                              },
                              child: const Text("OK"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );

        if (selected != null) {
          setState(() {
            controller.text = selected.join(', ');
          });
        }
      },
    ),
  );
}

  Widget _buildDropdownField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<String> items,
    String? Function(String?)? validator,
    void Function(String?)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: items.contains(controller.text) ? controller.text : null,
        decoration: _inputDecoration(label, icon),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: onChanged ?? (v) => controller.text = v ?? '',
        validator: validator,
        style: const TextStyle(color: Colors.black87),
      ),
    );
  }

  Widget _buildCheckboxGroup(
  List<String> options,
  Map<String, bool> selected,
  Function(Map<String, bool>) onChanged,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: options.map((backendKey) {
      return CheckboxListTile(
        title: Text(
          _skillLabels[backendKey] ?? backendKey,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        value: selected[backendKey] ?? false,
        activeColor: const Color(0xFFFF6F6F),
        checkColor: Colors.white,
        onChanged: (value) {
          setState(() {
            selected[backendKey] = value ?? false;
            onChanged(selected);
          });
        },
      );
    }).toList(),
  );
}
    }