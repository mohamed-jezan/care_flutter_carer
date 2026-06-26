// lib/screen/onboarding/OnboardingBackgroundPage.dart
//
// UI updated to match OnboardingSkillsPage card-based section pattern.
// All logic is identical to the original — only the build/widget layer changed.

import 'dart:io';
import 'package:call_care/widgets/three_dot_loader.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/onboarding_background.dart';
import '../../service/onboarding_background_service.dart';
import '../../service/onboarding_info_service.dart';
import '../loginScreens/signin_page.dart';

class OnboardingBackgroundPage extends StatefulWidget {
  final String userId;
  final String token;
  final String username;
  final String? selectedCountry;
  final VoidCallback? onBackgroundSaved;
  final PageController? controller;

  const OnboardingBackgroundPage({
    super.key,
    required this.userId,
    required this.token,
    required this.username,
    this.selectedCountry,
    this.onBackgroundSaved,
    this.controller,
  });

  @override
  _OnboardingBackgroundPageState createState() =>
      _OnboardingBackgroundPageState();
}

class _OnboardingBackgroundPageState extends State<OnboardingBackgroundPage> {
  final _formKey = GlobalKey<FormState>();
  late final OnboardingBackgroundService _service;
  late final OnboardingInfoService _infoService;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _yearsExperienceController = TextEditingController();
  final List<Map<String, TextEditingController>> _previousJobs = [];
  final List<Map<String, TextEditingController>> _references = [];
  final List<Map<String, dynamic>> _qualifications = [];
  Map<String, bool> _specialistTraining = {};
  Map<String, bool> _mandatoryTraining = {};
  final _dbsCertificateNumberController = TextEditingController();
  final _dbsIssueDateController = TextEditingController();

  // ── File state ─────────────────────────────────────────────────────────────
  File? _dbsCertificateFile;
  File? _cvFile;
  bool? _wwcc;

  // ── Page state ─────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _hasBackgroundCheck = false;
  bool _isDbsEditing = true;
  bool _isCvEditing = true;
  OnboardingBackground? _existingBackground;
  String? _selectedCountry;

  // ── Training options ───────────────────────────────────────────────────────
  final Map<String, List<String>> _specialistTrainingOptions = {
    'United Kingdom': ['Dementia care', 'Medication handling'],
    'Canada': ['Food Safety', 'Infection Control'],
    'Australia': ['Medication', 'Infection Control'],
    'Malaysia': ['Infection Control'],
  };
  final Map<String, List<String>> _mandatoryTrainingOptions = {
    'United Kingdom': ['First Aid', 'Safeguarding', 'Medication', 'Dementia care'],
    'Canada': ['First Aid', 'CPR', 'WHMIS'],
    'Australia': ['First Aid', 'CPR', 'Safeguarding'],
    'Malaysia': ['First Aid', 'BLS'],
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _service = OnboardingBackgroundService(widget.token);
    _infoService = OnboardingInfoService(widget.token);
    _addReference();
    _addReference();
    _fetchCountryAndInitialize();
  }

  @override
  void dispose() {
    _yearsExperienceController.dispose();
    _dbsCertificateNumberController.dispose();
    _dbsIssueDateController.dispose();
    for (var job in _previousJobs) {
      job['employer']!.dispose();
      job['title']!.dispose();
      job['start_date']!.dispose();
      job['end_date']!.dispose();
      job['reference_name']!.dispose();
      job['reference_phone']!.dispose();
      job['reference_email']!.dispose();
    }
    for (var ref in _references) {
      ref['name']!.dispose();
      ref['phone']!.dispose();
      ref['email']!.dispose();
    }
    for (var qual in _qualifications) {
      qual['title']!.dispose();
      qual['issued_by']!.dispose();
      qual['issue_date']!.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data & logic (unchanged from original)
  // ─────────────────────────────────────────────────────────────────────────

  double _calculateYearsOfExperience() {
    double totalYears = 0.0;
    final dateFormat = DateFormat('yyyy-MM-dd');
    for (var job in _previousJobs) {
      final startDateStr = job['start_date']!.text;
      final endDateStr = job['end_date']!.text;
      if (startDateStr.isNotEmpty && endDateStr.isNotEmpty) {
        try {
          final startDate = dateFormat.parse(startDateStr);
          final endDate = dateFormat.parse(endDateStr);
          final difference = endDate.difference(startDate);
          totalYears += difference.inDays / 365.0;
        } catch (e) {
          continue;
        }
      }
    }
    return double.parse(totalYears.toStringAsFixed(1));
  }

  void _updateYearsOfExperience() {
    final years = _calculateYearsOfExperience();
    setState(() => _yearsExperienceController.text = years.toString());
  }

  Future<void> _fetchCountryAndInitialize() async {
    setState(() => _isLoading = true);
    try {
      final checkResult =
          await _infoService.checkOnboardingInfoByUserId(widget.userId);
      if (checkResult['exists'] && checkResult['data'] != null) {
        final infoId = checkResult['data']['id'] as String;
        final onboardingInfo =
            await _infoService.getOnboardingInfoById(infoId);
        setState(() {
          _selectedCountry = onboardingInfo.country?.isNotEmpty == true
              ? onboardingInfo.country
              : (widget.selectedCountry?.isNotEmpty == true
                  ? widget.selectedCountry
                  : 'United Kingdom');
        });
        _initializeTrainingOptions(_selectedCountry!);
      } else {
        setState(() {
          _selectedCountry = widget.selectedCountry?.isNotEmpty == true
              ? widget.selectedCountry
              : 'United Kingdom';
        });
        _initializeTrainingOptions(_selectedCountry!);
        _showSnack('Please complete Personal Information first');
      }
      await _checkAndLoadExistingBackground();
    } catch (e) {
      if (e.toString().contains('Unauthorized')) {
        _redirectToSignIn();
      } else {
        setState(() => _selectedCountry = 'United Kingdom');
        _initializeTrainingOptions(_selectedCountry!);
        _showSnack('Error fetching country: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initializeTrainingOptions(String country) {
    final validCountry = _specialistTrainingOptions.containsKey(country)
        ? country
        : 'United Kingdom';
    setState(() {
      _specialistTraining = {
        for (var o in _specialistTrainingOptions[validCountry] ?? []) o: false
      };
      _mandatoryTraining = {
        for (var o in _mandatoryTrainingOptions[validCountry] ?? []) o: false
      };
    });
  }

  Future<void> _checkAndLoadExistingBackground() async {
    try {
      final response =
          await _service.getBackgroundChecksByUserId(widget.userId);
      if (response.isNotEmpty) {
        final background = response[0];
        setState(() {
          _hasBackgroundCheck = true;
          _existingBackground = background;
          _dbsCertificateNumberController.text =
              background.dbsCertificateNumber ?? '';
          _dbsIssueDateController.text = background.dbsIssueDate ?? '';
          _isDbsEditing = false;
          _isCvEditing = false;
          _wwcc = background.wwcc;

          _previousJobs.clear();
          background.previousJobs?.forEach((job) {
            _previousJobs.add({
              'employer': TextEditingController(text: job.employer),
              'title': TextEditingController(text: job.title),
              'start_date': TextEditingController(text: job.startDate),
              'end_date': TextEditingController(text: job.endDate),
              'reference_name': TextEditingController(text: job.referenceName),
              'reference_phone':
                  TextEditingController(text: job.referencePhone),
              'reference_email':
                  TextEditingController(text: job.referenceEmail),
            });
          });

          _references.clear();
          background.references?.forEach((ref) {
            _references.add({
              'name': TextEditingController(text: ref.name),
              'phone': TextEditingController(text: ref.phone),
              'email': TextEditingController(text: ref.email),
            });
          });

          _qualifications.clear();
          background.qualifications?.forEach((qual) {
            _qualifications.add({
              'id': const Uuid().v4(),
              'title': TextEditingController(text: qual.title),
              'issued_by': TextEditingController(text: qual.issuedBy),
              'issue_date': TextEditingController(text: qual.issueDate),
              'file': null,
              'file_url': qual.fileUrl,
              'file_key': qual.fileKey,
              'isExisting': qual.fileUrl != null,
              'isEditing': false,
            });
          });

          _specialistTraining = {
            for (var o
                in _specialistTrainingOptions[_selectedCountry] ?? [])
              o: background.specialistTraining?.contains(o) ?? false
          };
          _mandatoryTraining = {
            for (var o
                in _mandatoryTrainingOptions[_selectedCountry] ?? [])
              o: background.mandatoryTraining?.contains(o) ?? false
          };

          _updateYearsOfExperience();
        });
      } else {
        setState(() {
          _hasBackgroundCheck = false;
          _existingBackground = null;
          _isDbsEditing = true;
          _isCvEditing = true;
          _qualifications.clear();
          _previousJobs.clear();
          _references.clear();
          _yearsExperienceController.text = '0.0';
        });
        _showSnack(
            'No existing background checks found. Please fill out the form.');
      }
    } catch (e) {
      if (e.toString().contains('Unauthorized')) {
        _redirectToSignIn();
      } else if (e.toString().contains('No background checks found')) {
        setState(() {
          _hasBackgroundCheck = false;
          _existingBackground = null;
          _isDbsEditing = true;
          _isCvEditing = true;
          _qualifications.clear();
          _previousJobs.clear();
          _references.clear();
          _yearsExperienceController.text = '0.0';
        });
      } else {
        if (mounted) _showSnack('Error checking background: $e');
      }
    }
  }

  void _addPreviousJob() {
    setState(() {
      _previousJobs.add({
        'employer': TextEditingController(),
        'title': TextEditingController(),
        'start_date': TextEditingController(),
        'end_date': TextEditingController(),
        'reference_name': TextEditingController(),
        'reference_phone': TextEditingController(),
        'reference_email': TextEditingController(),
      });
      _updateYearsOfExperience();
    });
  }

  void _addReference() {
    setState(() {
      _references.add({
        'name': TextEditingController(),
        'phone': TextEditingController(),
        'email': TextEditingController(),
      });
    });
  }

  void _addQualification() {
    setState(() {
      _qualifications.add({
        'id': const Uuid().v4(),
        'title': TextEditingController(),
        'issued_by': TextEditingController(),
        'issue_date': TextEditingController(),
        'file': null,
        'file_url': null,
        'isExisting': false,
        'isEditing': true,
      });
    });
  }

  Future<void> _pickFile(String field, [int? qualIndex]) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        _showSnack('File size exceeds 10MB limit');
        return;
      }
      setState(() {
        if (field == 'dbs') {
          _dbsCertificateFile = file;
          _isDbsEditing = true;
        } else if (field == 'cv') {
          _cvFile = file;
          _isCvEditing = true;
        } else if (field == 'qualification' && qualIndex != null) {
          _qualifications[qualIndex]['file'] = file;
          _qualifications[qualIndex]['isEditing'] = true;
        }
      });
    }
  }

  Future<void> _viewFile(String fileUrl) async {
    final uri = Uri.parse(fileUrl);
    if (!await launchUrl(uri)) {
      _showSnack('Could not launch $fileUrl');
    }
  }

  Future<void> _selectDate(TextEditingController controller,
      {int? jobIndex}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFF6F6F),
            onPrimary: Colors.white,
            surface: Colors.white,
          ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(date);
      if (jobIndex != null) _updateYearsOfExperience();
    }
  }

  Future<void> _submitForm() async {
    if (_selectedCountry == null) {
      _showSnack('Please complete Personal Information first');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    if (_previousJobs.isEmpty &&
        _qualifications.isEmpty &&
        _cvFile == null &&
        _existingBackground?.cvFileUrl == null) {
      _showSnack(
          'At least one of previous jobs, qualifications, or CV is required');
      return;
    }
    for (var job in _previousJobs) {
      if (job['employer']!.text.isNotEmpty ||
          job['title']!.text.isNotEmpty ||
          job['start_date']!.text.isNotEmpty ||
          job['end_date']!.text.isNotEmpty) {
        if (job['employer']!.text.isEmpty ||
            job['title']!.text.isEmpty ||
            job['start_date']!.text.isEmpty) {
          _showSnack(
              'Previous jobs must have employer, title, and start date');
          return;
        }
      }
    }
    for (var qual in _qualifications) {
      if (qual['title']!.text.isNotEmpty &&
          (qual['file'] == null && qual['file_url'] == null)) {
        _showSnack('Each qualification must have a file uploaded');
        return;
      }
    }
    if (_references.length < 2) {
      _showSnack('At least two references are required');
      return;
    }
    if (_dbsCertificateFile == null &&
        _existingBackground?.dbsFileUrl == null) {
      _showSnack('DBS certificate file is required');
      return;
    }
    if (_selectedCountry == 'Australia' && _wwcc == null) {
      _showSnack(
          'Working with Children Check is required for Australia');
      return;
    }

    setState(() => _isLoading = true);
    _showSnack('Uploading files, please wait...');

    try {
      final previousJobs = _previousJobs
          .map((job) => PreviousJob(
                employer: job['employer']!.text.isEmpty
                    ? null
                    : job['employer']!.text,
                title:
                    job['title']!.text.isEmpty ? null : job['title']!.text,
                startDate: job['start_date']!.text.isEmpty
                    ? null
                    : job['start_date']!.text,
                endDate: job['end_date']!.text.isEmpty
                    ? null
                    : job['end_date']!.text,
                referenceName: job['reference_name']!.text.isEmpty
                    ? null
                    : job['reference_name']!.text,
                referencePhone: job['reference_phone']!.text.isEmpty
                    ? null
                    : job['reference_phone']!.text,
                referenceEmail: job['reference_email']!.text.isEmpty
                    ? null
                    : job['reference_email']!.text,
              ))
          .toList();

      final references = _references
          .map((ref) => Reference(
                name: ref['name']!.text,
                phone: ref['phone']!.text,
                email: ref['email']!.text,
              ))
          .toList();

      final qualifications = _qualifications
          .where((qual) => qual['title']!.text.isNotEmpty)
          .map((qual) => Qualification(
                title: qual['title']!.text,
                issuedBy: qual['issued_by']!.text,
                issueDate: qual['issue_date']!.text,
                fileUrl: qual['file_url'],
                fileKey: qual['file_key'],
              ))
          .toList();

      final qualificationFiles = _qualifications
          .where((qual) => qual['file'] != null)
          .map((qual) => qual['file'] as File)
          .toList();

      final specialistTrainingList = _specialistTraining.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      final mandatoryTrainingList = _mandatoryTraining.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final yearsExperience = _calculateYearsOfExperience().toInt();

      if (_hasBackgroundCheck) {
        await _service.updateBackgroundCheck(
          userId: widget.userId,
          yearsExperience: yearsExperience,
          previousJobs: previousJobs,
          references: references,
          qualifications: qualifications,
          specialistTraining: specialistTrainingList,
          mandatoryTraining: mandatoryTrainingList,
          dbsCertificateNumber: _dbsCertificateNumberController.text,
          dbsIssueDate: _dbsIssueDateController.text,
          dbsCertificateFile: _dbsCertificateFile,
          cvFile: _cvFile,
          qualificationFiles: qualificationFiles,
          wwcc: _wwcc,
          updatedBy: widget.userId,
        );
        setState(() {
          _isDbsEditing = _dbsCertificateFile == null &&
                  _existingBackground?.dbsFileUrl != null
              ? false
              : true;
          _isCvEditing =
              _cvFile == null && _existingBackground?.cvFileUrl != null
                  ? false
                  : true;
          for (var qual in _qualifications) {
            qual['isEditing'] =
                qual['file'] == null && qual['file_url'] != null
                    ? false
                    : true;
            qual['isExisting'] = qual['file_url'] != null;
          }
        });
        _showSnack('Background check updated successfully');
        await _checkAndLoadExistingBackground();
        widget.onBackgroundSaved?.call();
        widget.controller?.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        await _service.createBackgroundCheck(
          userId: widget.userId,
          yearsExperience: yearsExperience,
          previousJobs: previousJobs,
          references: references,
          qualifications: qualifications,
          specialistTraining: specialistTrainingList,
          mandatoryTraining: mandatoryTrainingList,
          dbsCertificateNumber: _dbsCertificateNumberController.text,
          dbsIssueDate: _dbsIssueDateController.text,
          dbsCertificateFile: _dbsCertificateFile!,
          cvFile: _cvFile,
          qualificationFiles: qualificationFiles,
          wwcc: _wwcc,
          createdBy: widget.userId,
        );
        setState(() {
          _hasBackgroundCheck = true;
          _isDbsEditing = _dbsCertificateFile == null &&
                  _existingBackground?.dbsFileUrl != null
              ? false
              : true;
          _isCvEditing =
              _cvFile == null && _existingBackground?.cvFileUrl != null
                  ? false
                  : true;
          for (var qual in _qualifications) {
            qual['isEditing'] =
                qual['file'] == null && qual['file_url'] != null
                    ? false
                    : true;
            qual['isExisting'] = qual['file_url'] != null;
          }
        });
        _showSnack('Background check created successfully');
        await _checkAndLoadExistingBackground();
        widget.onBackgroundSaved?.call();
        widget.controller?.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      if (e.toString().contains('Unauthorized')) {
        _redirectToSignIn();
      } else {
        _showSnack('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _showSnack(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
    ));
  }

  void _redirectToSignIn() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignInPage()),
    );
    _showSnack('Session expired, please log in again');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final validCountry =
        _selectedCountry != null &&
                _specialistTrainingOptions.containsKey(_selectedCountry!)
            ? _selectedCountry!
            : 'United Kingdom';
    final specialistTrainingOptions =
        _specialistTrainingOptions[validCountry] ?? [];
    final mandatoryTrainingOptions =
        _mandatoryTrainingOptions[validCountry] ?? [];

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
          child: _isLoading
              ? const Center(
                  child: ThreeDotLoader(
                    color: Color(0xFFFF6F6F),
                  ),
                )
              : _selectedCountry == null
                  ? _buildNoCountryPlaceholder()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),

                            // ── Section: Previous Jobs ──────────────────────
                            _buildSectionCard(
                              title: 'Previous Jobs',
                              icon: Icons.work_history_outlined,
                              isSaved: _hasBackgroundCheck &&
                                  _previousJobs.isNotEmpty,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  ..._previousJobs
                                      .asMap()
                                      .entries
                                      .map((entry) => _buildJobCard(
                                          entry.key, entry.value)),
                                  const SizedBox(height: 8),
                                  _buildAddButton(
                                    label: 'Add New Job',
                                    onPressed: _addPreviousJob,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTextField(
                                    controller: _yearsExperienceController,
                                    label: 'Years of Experience',
                                    icon: Icons.timelapse,
                                    readOnly: true,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Section: References ─────────────────────────
                            _buildSectionCard(
                              title: 'References',
                              icon: Icons.people_outline,
                              isSaved: _hasBackgroundCheck &&
                                  _references.isNotEmpty,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  ..._references
                                      .asMap()
                                      .entries
                                      .map((entry) => _buildReferenceCard(
                                          entry.key, entry.value)),
                                  const SizedBox(height: 8),
                                  _buildAddButton(
                                    label: 'Add New Reference',
                                    onPressed: _addReference,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Section: Qualifications ─────────────────────
                            _buildSectionCard(
                              title: 'Qualifications',
                              icon: Icons.school_outlined,
                              isSaved: _hasBackgroundCheck &&
                                  _qualifications.isNotEmpty,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  ..._qualifications
                                      .asMap()
                                      .entries
                                      .map((entry) =>
                                          _buildQualificationCard(
                                              entry.key, entry.value)),
                                  const SizedBox(height: 8),
                                  _buildAddButton(
                                    label: 'Add New Qualification',
                                    onPressed: _addQualification,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Section: Training ───────────────────────────
                            _buildSectionCard(
                              title: 'Training',
                              icon: Icons.medical_information_outlined,
                              isSaved: _hasBackgroundCheck,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  if (specialistTrainingOptions
                                      .isNotEmpty) ...[
                                    _buildCheckboxGroup(
                                      'Specialist Training',
                                      specialistTrainingOptions,
                                      _specialistTraining,
                                      (updated) => setState(
                                          () => _specialistTraining =
                                              updated),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  _buildCheckboxGroup(
                                    'Mandatory Training',
                                    mandatoryTrainingOptions,
                                    _mandatoryTraining,
                                    (updated) => setState(
                                        () => _mandatoryTraining = updated),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Section: DBS Certificate ────────────────────
                            _buildSectionCard(
                              title: 'DBS Certificate',
                              icon: Icons.verified_outlined,
                              isSaved: _hasBackgroundCheck &&
                                  (_existingBackground?.dbsFileUrl != null ||
                                      _dbsCertificateFile != null),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _buildTextField(
                                    controller:
                                        _dbsCertificateNumberController,
                                    label: 'DBS Certificate Number',
                                    icon: Icons.numbers,
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                  _buildTextField(
                                    controller: _dbsIssueDateController,
                                    label: 'DBS Issue Date',
                                    icon: Icons.calendar_today,
                                    readOnly: true,
                                    onTap: () =>
                                        _selectDate(_dbsIssueDateController),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                  _buildFileDisplay(
                                    'DBS Certificate File',
                                    _existingBackground?.dbsFileUrl,
                                    'dbs',
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Section: CV ─────────────────────────────────
                            _buildSectionCard(
                              title: 'CV / Resume',
                              icon: Icons.description_outlined,
                              isSaved: _hasBackgroundCheck &&
                                  (_existingBackground?.cvFileUrl != null ||
                                      _cvFile != null),
                              child: _buildFileDisplay(
                                'Upload CV',
                                _existingBackground?.cvFileUrl,
                                'cv',
                              ),
                            ),

                            // ── Section: WWCC (Australia only) ──────────────
                            if (validCountry == 'Australia') ...[
                              const SizedBox(height: 20),
                              _buildSectionCard(
                                title: 'Working with Children Check',
                                icon: Icons.child_care,
                                isSaved: _hasBackgroundCheck &&
                                    _wwcc != null,
                                child: DropdownButtonFormField<bool>(
                                  value: _wwcc,
                                  decoration: _inputDecoration(
                                    'Working with Children Check',
                                    Icons.child_care,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: true, child: Text('Yes')),
                                    DropdownMenuItem(
                                        value: false, child: Text('No')),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _wwcc = v),
                                  validator: (v) =>
                                      v == null ? 'Required' : null,
                                  style: const TextStyle(
                                      color: Colors.black87),
                                ),
                              ),
                            ],

                            const SizedBox(height: 32),

                            // ── Submit / Update button ──────────────────────
                            _buildSubmitButton(),

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
  // Reusable section card (matches skills page pattern)
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
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isSaved
              ? const Color(0xFFFF6F6F).withOpacity(0.5)
              : const Color(0xFFFF6F6F).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSaved
                  ? const Color(0xFFFF6F6F).withOpacity(0.08)
                  : const Color(0xFFFF6F6F).withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSaved ? const Color(0xFFFF6F6F) : const Color(0xFFFF6F6F),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isSaved ? const Color(0xFFFF6F6F) : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (isSaved)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6F6F).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green, size: 13),
                        SizedBox(width: 4),
                        Text(
                          'Saved',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sub-cards for list items
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildJobCard(
      int index, Map<String, TextEditingController> job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Job ${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFFFF6F6F)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _previousJobs.removeAt(index);
                    _updateYearsOfExperience();
                  }),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildTextField(
                controller: job['employer']!,
                label: 'Employer',
                icon: Icons.business),
            _buildTextField(
                controller: job['title']!,
                label: 'Title',
                icon: Icons.work_outline),
            _buildTextField(
              controller: job['start_date']!,
              label: 'Start Date',
              icon: Icons.calendar_today,
              readOnly: true,
              onTap: () =>
                  _selectDate(job['start_date']!, jobIndex: index),
            ),
            _buildTextField(
              controller: job['end_date']!,
              label: 'End Date',
              icon: Icons.calendar_today,
              readOnly: true,
              onTap: () =>
                  _selectDate(job['end_date']!, jobIndex: index),
            ),
            _buildTextField(
                controller: job['reference_name']!,
                label: 'Reference Name',
                icon: Icons.person),
            _buildTextField(
              controller: job['reference_phone']!,
              label: 'Reference Phone',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v!.isNotEmpty &&
                    !RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(v)) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
            _buildTextField(
              controller: job['reference_email']!,
              label: 'Reference Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v!.isNotEmpty &&
                    !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(v)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceCard(
      int index, Map<String, TextEditingController> ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Reference ${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFFFF6F6F)),
                ),
                const Spacer(),
                if (index >= 2)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _references.removeAt(index)),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: ref['name']!,
              label: 'Name',
              icon: Icons.person,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            _buildTextField(
              controller: ref['phone']!,
              label: 'Phone',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v!.isEmpty) return 'Required';
                if (!RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(v)) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
            _buildTextField(
              controller: ref['email']!,
              label: 'Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v!.isEmpty) return 'Required';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(v)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualificationCard(
      int index, Map<String, dynamic> qual) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Qualification ${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFFFF6F6F)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      setState(() => _qualifications.removeAt(index)),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: qual['title']!,
              label: 'Qualification Title',
              icon: Icons.school,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            _buildTextField(
              controller: qual['issued_by']!,
              label: 'Issued By',
              icon: Icons.business,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            _buildTextField(
              controller: qual['issue_date']!,
              label: 'Issue Date',
              icon: Icons.calendar_today,
              readOnly: true,
              onTap: () => _selectDate(qual['issue_date']!),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            _buildFileDisplay(
              'Qualification File',
              qual['file_url'],
              'qualification',
              index,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared widget builders
  // ─────────────────────────────────────────────────────────────────────────

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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool readOnly = false,
    TextInputType? keyboardType,
    Function()? onTap,
    String? Function(String?)? validator,
    int? jobIndex,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        onTap: onTap,
        validator: validator,
        onChanged:
            jobIndex != null ? (_) => _updateYearsOfExperience() : null,
        decoration: _inputDecoration(label, icon ?? Icons.edit),
        style: const TextStyle(color: Colors.black87, fontSize: 14),
      ),
    );
  }

  Widget _buildCheckboxGroup(
    String title,
    List<String> options,
    Map<String, bool> selectedOptions,
    Function(Map<String, bool>) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87),
        ),
        const SizedBox(height: 4),
        ...options.map((option) => CheckboxListTile(
              title: Text(option,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87)),
              value: selectedOptions[option] ?? false,
              activeColor: const Color(0xFFFF6F6F),
              checkColor: Colors.white,
              onChanged: (v) => setState(() {
                selectedOptions[option] = v ?? false;
                onChanged(selectedOptions);
              }),
            )),
      ],
    );
  }

  Widget _buildFileDisplay(String label, String? fileUrl, String field,
      [int? qualIndex]) {
    final hasNewFile = (field == 'dbs' && _dbsCertificateFile != null) ||
        (field == 'cv' && _cvFile != null) ||
        (field == 'qualification' &&
            qualIndex != null &&
            _qualifications[qualIndex]['file'] != null);

    final bool isEditing = field == 'dbs'
        ? _isDbsEditing
        : field == 'cv'
            ? _isCvEditing
            : qualIndex != null
                ? _qualifications[qualIndex]['isEditing']
                : true;

    String buttonText;
    if (field == 'dbs' && _dbsCertificateFile != null) {
      buttonText = _dbsCertificateFile!.path.split('/').last;
    } else if (field == 'cv' && _cvFile != null) {
      buttonText = _cvFile!.path.split('/').last;
    } else if (field == 'qualification' &&
        qualIndex != null &&
        _qualifications[qualIndex]['file'] != null) {
      buttonText =
          (_qualifications[qualIndex]['file'] as File).path.split('/').last;
    } else if (fileUrl != null) {
      buttonText = Uri.parse(fileUrl).pathSegments.last;
    } else {
      buttonText =
          'Upload ${field == 'dbs' ? 'DBS Certificate' : field == 'cv' ? 'CV' : 'File'}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (isEditing || fileUrl == null) {
                    _pickFile(field, qualIndex);
                  } else {
                    _viewFile(fileUrl);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFFF6F6F),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(
                      color: Color(0xFFFF6F6F), width: 1),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                icon: Icon(
                  hasNewFile || fileUrl != null
                      ? (isEditing ? Icons.upload_file : Icons.visibility)
                      : Icons.upload_file,
                  size: 18,
                  color: const Color(0xFFFF6F6F),
                ),
                label: Text(
                  buttonText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFFFF6F6F), fontSize: 13),
                ),
              ),
            ),
            if (fileUrl != null && !isEditing)
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFFFF6F6F)),
                onPressed: () => setState(() {
                  if (field == 'dbs') {
                    _isDbsEditing = true;
                  } else if (field == 'cv') {
                    _isCvEditing = true;
                  } else if (field == 'qualification' &&
                      qualIndex != null) {
                    _qualifications[qualIndex]['isEditing'] = true;
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }

  /// Gradient "Add" button used inside sections.
  Widget _buildAddButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 4,
        shadowColor: Colors.black26,
      ),
      icon: const Icon(Icons.add, color: Colors.white, size: 18),
      label: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6F6F), Color(0xFFFFA6A6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ),
      ),
    );
  }

  /// Full-width Submit / Update button at the bottom.
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitForm,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30)),
        elevation: 5,
        shadowColor: Colors.black26,
      ),
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6F6F), Color(0xFFFFA6A6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
        child: Container(
          alignment: Alignment.center,
          constraints:
              const BoxConstraints(minWidth: double.infinity, minHeight: 48),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: ThreeDotLoader(
                      color: Colors.white, size: 6),
                )
              : Text(
                  _hasBackgroundCheck ? 'Update' : 'Submit',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  /// Shown when country info is not yet available.
  Widget _buildNoCountryPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Please complete Personal Information first',
            style: TextStyle(color: Colors.black54, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 5,
            ),
            child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6F6F), Color(0xFFFFA6A6)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.all(Radius.circular(30)),
              ),
              child: Container(
                alignment: Alignment.center,
                constraints:
                    const BoxConstraints(minWidth: 88, minHeight: 36),
                child: const Text(
                  'Go Back',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}