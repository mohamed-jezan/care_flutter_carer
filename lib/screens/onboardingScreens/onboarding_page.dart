
import 'package:flutter/material.dart';
import 'onboarding_info_page.dart';
import 'onboarding_identity_check_page.dart';
import 'onboarding_background_page.dart';
import 'onboarding_skills_page.dart';
import '../../service/onboarding_info_service.dart';
import '../../service/onboarding_identity_check_service.dart';
import '../../service/onboarding_background_service.dart';
import '../../service/onboarding_skills_service.dart';
import '../../model/onboarding_info.dart';
import '../onboardingScreens/onboarding_bank_details_page.dart';

class OnboardingPage extends StatefulWidget {
  final String token;
  final String userId;
  final String username;

  const OnboardingPage({
    super.key,
    required this.token,
    required this.userId,
    required this.username,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int currentStep = 0;
  bool _isChecking = false;
  String? selectedCountry;

  bool _isPersonalInfoComplete = false;
  bool _isIdentityComplete = false;
  bool _isBackgroundComplete = false;
  bool _isSkillsComplete = false;

  @override
  void initState() {
    super.initState();
    _checkStepCompletion();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step completion checker (runs on init and after each save)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _checkStepCompletion() async {
    try {
      // ── Personal Information ──────────────────────────────────────────────
      final infoResult = await OnboardingInfoService(widget.token)
          .checkOnboardingInfoByUserId(widget.userId);
      final infoExists = infoResult['exists'] as bool? ?? false;
      final isInfoValid = infoExists && await _validatePersonalInfoStep();

      // ── Identity Verification ─────────────────────────────────────────────
      final identityResult = await OnboardingIdentityCheckService(widget.token)
          .checkIdentityByUserId(widget.userId);
      final identityExists = identityResult['exists'] as bool? ?? false;
      final isIdentityValid = identityExists && await _validateIdentityStep();

      // ── Background Verification ───────────────────────────────────────────
      final backgroundResult = await OnboardingBackgroundService(widget.token)
          .getBackgroundChecksByUserId(widget.userId);
      final backgroundExists = backgroundResult != '';
      final isBackgroundValid =
          backgroundExists && await _validateBackgroundStep();

      // ── Skills & Availability ─────────────────────────────────────────────
      // checkCarerSkillsByUserId now returns a named record: ({bool exists, List<CarerSkill> rows})
      final skillsResult = await OnboardingSkillsService(widget.token)
          .checkCarerSkillsByUserId(widget.userId);
      final skillsExists = skillsResult.exists;
      final isSkillsValid = skillsExists && await _validateSkillsStep();

      if (mounted) {
        setState(() {
          _isPersonalInfoComplete = isInfoValid;
          _isIdentityComplete = isIdentityValid;
          _isBackgroundComplete = isBackgroundValid;
          _isSkillsComplete = isSkillsValid;
        });
      }
    } catch (e) {
      // Silently ignore — step indicators simply stay incomplete
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _tryGoNextStep(int targetStep) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      // ── Step 0 must be done before going to step 1+ ───────────────────────
      if (targetStep > 0) {
        final infoResult = await OnboardingInfoService(widget.token)
            .checkOnboardingInfoByUserId(widget.userId);
        if (infoResult['exists'] != true) {
          _showError('Please complete Personal Information first');
          return;
        }
        if (!await _validatePersonalInfoStep()) {
          _showError(
              'Please fill all required fields in Personal Information');
          return;
        }
      }

      // ── Step 1 must be done before going to step 2+ ───────────────────────
      if (targetStep > 1) {
        final identityResult =
            await OnboardingIdentityCheckService(widget.token)
                .checkIdentityByUserId(widget.userId);
        if (identityResult['exists'] != true) {
          _showError('Please complete Identity Verification first');
          return;
        }
        if (!await _validateIdentityStep()) {
          _showError('Please complete Identity Verification');
          return;
        }
      }

      // ── Step 2 must be done before going to step 3+ ───────────────────────
      if (targetStep > 2) {
        final backgroundResult =
            await OnboardingBackgroundService(widget.token)
                .getBackgroundChecksByUserId(widget.userId);
        if (backgroundResult == '') {
          _showError('Please complete Background Verification first');
          return;
        }
        if (!await _validateBackgroundStep()) {
          _showError('Please complete Background Verification');
          return;
        }
      }

      // ── Step 3 must be done before going to step 4 ────────────────────────
      if (targetStep > 3) {
        // checkCarerSkillsByUserId returns ({bool exists, List<CarerSkill> rows})
        final skillsResult = await OnboardingSkillsService(widget.token)
            .checkCarerSkillsByUserId(widget.userId);
        if (!skillsResult.exists) {
          _showError('Please complete Skills & Availability first');
          return;
        }
        if (!await _validateSkillsStep()) {
          _showError('Please complete all required skills fields');
          return;
        }
      }

      _goToStep(targetStep);
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _goToStep(int step) {
    setState(() => currentStep = step);
    _controller.animateToPage(
      step,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void goToPreviousStep() {
    if (currentStep > 0) _goToStep(currentStep - 1);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step validators
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _validatePersonalInfoStep() async {
    try {
      final result = await OnboardingInfoService(widget.token)
          .checkOnboardingInfoByUserId(widget.userId);
      if (result['exists'] == true && result['data'] != null) {
        final info = OnboardingInfo.fromJson(result['data']);
        return info.dob != null &&
            info.dob!.isNotEmpty &&
            info.gender != null &&
            info.gender!.isNotEmpty &&
            info.nationalityId != null &&
            info.nationalityId!.isNotEmpty &&
            info.street != null &&
            info.street!.isNotEmpty &&
            info.city != null &&
            info.city!.isNotEmpty &&
            info.postCode != null &&
            info.postCode!.isNotEmpty &&
            info.country != null &&
            info.country!.isNotEmpty &&
            info.emerContactName != null &&
            info.emerContactName!.isNotEmpty &&
            info.emerRelationship != null &&
            info.emerRelationship!.isNotEmpty &&
            info.emerPhone != null &&
            info.emerPhone!.isNotEmpty;
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error validating personal info: $e')),
        );
      }
      return false;
    }
  }

  Future<bool> _validateIdentityStep() async {
    return true; // Update with actual validation logic if available
  }

  Future<bool> _validateBackgroundStep() async {
    return true; // Update with actual validation logic if available
  }

  /// Skills are valid when:
  ///   - At least one skill row exists
  ///   - At least one language row exists (primary)
  ///   - A preference row exists with gender and part_time_preference filled
  Future<bool> _validateSkillsStep() async {
    try {
      final service = OnboardingSkillsService(widget.token);

      // 1. Check skills — at least one row required
      final skillsResult =
          await service.checkCarerSkillsByUserId(widget.userId);
      if (!skillsResult.exists || skillsResult.rows.isEmpty) return false;

      // 2. Check languages — at least a primary language row required
      final langResult =
          await service.checkCarerLanguagesByUserId(widget.userId);
      if (!langResult.exists || langResult.rows.isEmpty) return false;
      final hasPrimary = langResult.rows.any((r) => r.isPrimary);
      if (!hasPrimary) return false;

      // 3. Check preferences — must have gender and part_time_preference
      final prefResult =
          await service.checkCarerPreferenceByUserId(widget.userId);
      if (!prefResult.exists || prefResult.preference == null) return false;
      final pref = prefResult.preference!;
      if (pref.preferredClientGender.isEmpty) return false;
      if (pref.partTimePreference.isEmpty) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stepper helpers
  // ─────────────────────────────────────────────────────────────────────────

  String getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Personal Information';
      case 1:
        return 'Identity Verification';
      case 2:
        return 'Background Verification';
      case 3:
        return 'Skills Verification';
      case 4:
        return 'Bank Details';
      default:
        return '';
    }
  }

  List<Step> getSteps() => [
        Step(
          isActive: currentStep >= 0,
          state: _isPersonalInfoComplete
              ? StepState.complete
              : StepState.indexed,
          title: const Text(''),
          content: const SizedBox.shrink(),
        ),
        Step(
          isActive: currentStep >= 1,
          state:
              _isIdentityComplete ? StepState.complete : StepState.indexed,
          title: const Text(''),
          content: const SizedBox.shrink(),
        ),
        Step(
          isActive: currentStep >= 2,
          state: _isBackgroundComplete
              ? StepState.complete
              : StepState.indexed,
          title: const Text(''),
          content: const SizedBox.shrink(),
        ),
        Step(
          isActive: currentStep >= 3,
          state:
              _isSkillsComplete ? StepState.complete : StepState.indexed,
          title: const Text(''),
          content: const SizedBox.shrink(),
        ),
        Step(
          isActive: currentStep >= 4,
          state: StepState.indexed,
          title: const Text(''),
          content: const SizedBox.shrink(),
        ),
      ];

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          getStepTitle(currentStep),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 252, 164, 164),
      ),
      body: Column(
        children: [
          // ── Stepper indicator ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: Colors.white10,
            child: SizedBox(
              height: 80,
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: Colors.white,
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: const Color.fromARGB(255, 253, 123, 116),
                        onSurface:
                            const Color.fromARGB(255, 250, 146, 146),
                      ),
                ),
                child: Stepper(
                  type: StepperType.horizontal,
                  steps: getSteps(),
                  currentStep: currentStep,
                  onStepTapped: (index) => _tryGoNextStep(index),
                  controlsBuilder: (context, details) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // ── Page views ────────────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => currentStep = index),
              children: [
                OnboardingInfoPage(
                  token: widget.token,
                  userId: widget.userId,
                  username: widget.username,
                  controller: _controller,
                  onInfoSaved: _checkStepCompletion,
                  onCountrySelected: (country) {
                    setState(() => selectedCountry = country);
                  },
                ),
                OnboardingIdentityCheckPage(
                  token: widget.token,
                  userId: widget.userId,
                  username: widget.username,
                  controller: _controller,
                  onDocumentsSaved: _checkStepCompletion,
                ),
                OnboardingBackgroundPage(
                  userId: widget.userId,
                  token: widget.token,
                  username: widget.username,
                  selectedCountry: selectedCountry ?? '',
                  onBackgroundSaved: _checkStepCompletion,
                ),
                OnboardingSkillsPage(
                  userId: widget.userId,
                  token: widget.token,
                  username: widget.username,
                  email: widget.username,
                  controller: _controller,
                  onSkillsSaved: _checkStepCompletion,
                ),
                OnboardingBankDetailsPage(
                  token: widget.token,
                  userId: widget.userId,
                  email: widget.username,
                ),
              ],
            ),
          ),

          // ── Loading indicator ─────────────────────────────────────────────
          if (_isChecking)
            const LinearProgressIndicator(
              color: Color(0xFFFF6F6F),
              minHeight: 3,
            ),
        ],
      ),
    );
  }
}