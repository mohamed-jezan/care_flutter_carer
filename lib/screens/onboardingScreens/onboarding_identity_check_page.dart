// lib/screen/onboarding/OnboardingIdentityCheckPage.dart
//
// UI updated to match the card-based section pattern used in
// OnboardingSkillsPage and OnboardingBackgroundPage.
// All logic is identical to the original — only the build/widget layer changed.

import 'dart:io';
import 'package:call_care/widgets/three_dot_loader.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/onboarding_identity_check.dart';
import '../../service/onboarding_info_service.dart';
import '../../service/onboarding_identity_check_service.dart';
import '../loginScreens/signin_page.dart';

class OnboardingIdentityCheckPage extends StatefulWidget {
  final String token;
  final String userId;
  final String username;
  final VoidCallback? onDocumentsSaved;
  final PageController? controller;

  const OnboardingIdentityCheckPage({
    Key? key,
    required this.token,
    required this.userId,
    required this.username,
    this.onDocumentsSaved,
    this.controller,
  }) : super(key: key);

  @override
  _OnboardingIdentityCheckPageState createState() =>
      _OnboardingIdentityCheckPageState();
}

class _OnboardingIdentityCheckPageState
    extends State<OnboardingIdentityCheckPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final OnboardingIdentityCheckService _identityService;
  late final OnboardingInfoService _infoService;

  final List<Map<String, dynamic>> _documents = [];
  final List<File?> _files = [];

  bool _isLoading = false;
  bool _isDocumentsSaved = false;
  String? _selectedCountry;

  late AnimationController _animationController;
  late Animation<double> fadeAnimation;

  // ── Document type maps ─────────────────────────────────────────────────────
  final Map<String, List<String>> _countryDocuments = {
    'United Kingdom': [
      'Passport / BRP',
      'Right to Work',
      'Proof of Address',
      'Driving License',
      'Profile Picture',
      'National Insurance Number',
      'Share Code'
    ],
    'Canada': [
      'Passport / PR / Work Permit',
      'Proof of Address',
      'Driving License',
      'Profile Picture',
      'Social Insurance Number (SIN)'
    ],
    'Australia': [
      'Passport / PR / Visa',
      'Proof of Address',
      'Driving License',
      'Profile Picture',
      'Tax File Number (TFN)'
    ],
    'Malaysia': [
      'Passport / MyKad',
      'Proof of Address',
      'Driving License',
      'Profile Picture',
      'Work Permit'
    ],
  };

  final Map<String, String> _displayToDbMapping = {
    'Passport / BRP': 'passport',
    'Passport / PR / Work Permit': 'passport',
    'Passport / PR / Visa': 'passport',
    'Passport / MyKad': 'passport',
    'Passport': 'passport',
    'Right to Work': 'right to work',
    'Proof of Address': 'proof of address',
    'Driving License': 'driving licence',
    'Profile Picture': 'profile picture',
    'National Insurance Number': 'tax no',
    'Social Insurance Number (SIN)': 'tax no',
    'Tax File Number (TFN)': 'tax no',
    'Work Permit': 'tax no',
    'Share Code': 'share code',
  };

  // Document type icons for the card headers
  final Map<String, IconData> _docTypeIcons = {
    'passport': Icons.book_outlined,
    'right to work': Icons.work_outline,
    'proof of address': Icons.home_outlined,
    'driving licence': Icons.drive_eta_outlined,
    'profile picture': Icons.person_outline,
    'tax no': Icons.numbers,
    'share code': Icons.qr_code,
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _identityService = OnboardingIdentityCheckService(widget.token);
    _infoService = OnboardingInfoService(widget.token);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchCountryAndDocuments();
  }

  @override
  void dispose() {
    for (var doc in _documents) {
      (doc['controller'] as TextEditingController?)?.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data & logic (unchanged from original)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _fetchCountryAndDocuments() async {
    setState(() => _isLoading = true);
    try {
      final checkResult =
          await _infoService.checkOnboardingInfoByUserId(widget.userId);
      if (checkResult['exists'] && checkResult['data'] != null) {
        final infoId = checkResult['data']['id'] as String;
        final onboardingInfo =
            await _infoService.getOnboardingInfoById(infoId);
        setState(() {
          _selectedCountry = onboardingInfo.country;
          if (_selectedCountry != null &&
              _countryDocuments.containsKey(_selectedCountry)) {
            _documents.clear();
            _files.clear();
            for (var docType in _countryDocuments[_selectedCountry]!) {
              _documents.add({
                'id': const Uuid().v4(),
                'display_type': docType,
                'document_type': _displayToDbMapping[docType],
                'document_number': null,
                'file': null,
                'file_url': null,
                'controller': TextEditingController(),
                'isExisting': false,
                'isEditing': true,
              });
              _files.add(null);
            }
          } else {
            _documents.clear();
            _files.clear();
          }
        });
      }
      await _fetchExistingDocuments();
    } catch (e) {
      if (e.toString().contains('Unauthorized')) {
        _redirectToSignIn();
      } else {
        _showSnack('Error fetching country: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchExistingDocuments() async {
    try {
      final result =
          await _identityService.checkIdentityByUserId(widget.userId);
      if (result['exists']) {
        final documents =
            await _identityService.getIdentityChecksByUserId(widget.userId);
        setState(() {
          _documents.clear();
          _files.clear();
          final countryDocs = _countryDocuments[_selectedCountry] ?? [];
          final existingDocTypes = <String>{};

          for (var doc in documents) {
            existingDocTypes.add(doc.documentType);
            final displayType = countryDocs.firstWhere(
              (type) => _displayToDbMapping[type] == doc.documentType,
              orElse: () => doc.documentType,
            );
            _documents.add({
              'id': doc.id,
              'display_type': displayType,
              'document_type': doc.documentType,
              'document_number': doc.documentNumber,
              'file': null,
              'file_url': doc.fileUrl,
              'controller':
                  TextEditingController(text: doc.documentNumber ?? ''),
              'isExisting': true,
              'isEditing': false,
            });
            _files.add(null);
          }

          for (var docTypeDisplay in countryDocs) {
            final dbType = _displayToDbMapping[docTypeDisplay];
            if (!existingDocTypes.contains(dbType)) {
              _documents.add({
                'id': const Uuid().v4(),
                'display_type': docTypeDisplay,
                'document_type': dbType,
                'document_number': null,
                'file': null,
                'file_url': null,
                'controller': TextEditingController(),
                'isExisting': false,
                'isEditing': true,
              });
              _files.add(null);
            }
          }

          _isDocumentsSaved = true;
          _animationController.forward();
        });
      } else if (_selectedCountry != null && _documents.isEmpty) {
        _initializeDocuments();
      }
    } catch (e) {
      if (e.toString().contains('Unauthorized')) {
        _redirectToSignIn();
      } else {
        _showSnack('Error fetching documents: $e');
      }
    }
  }

  void _initializeDocuments() {
    if (_selectedCountry != null &&
        _countryDocuments.containsKey(_selectedCountry)) {
      setState(() {
        _documents.clear();
        _files.clear();
        for (var docType in _countryDocuments[_selectedCountry]!) {
          _documents.add({
            'id': const Uuid().v4(),
            'display_type': docType,
            'document_type': _displayToDbMapping[docType],
            'document_number': null,
            'file': null,
            'file_url': null,
            'controller': TextEditingController(),
            'isExisting': false,
            'isEditing': true,
          });
          _files.add(null);
        }
      });
    }
  }

  Future<void> _pickFile(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        final file = File(result.files.single.path!);
        _documents[index]['file'] = file;
        _files[index] = file;
      });
    }
  }

  Future<void> _viewFile(String fileUrl) async {
    final uri = Uri.parse(fileUrl);
    if (!await launchUrl(uri)) {
      _showSnack('Could not launch $fileUrl');
    }
  }

  Future<void> _saveOrUpdateDocuments() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final validDocuments = <OnboardingIdentityCheck>[];
      final validFiles = <File>[];
      bool hasAtLeastOneRequiredDocument = false;

      for (int i = 0; i < _documents.length; i++) {
        final doc = _documents[i];
        var docType = doc['document_type'] as String;

        if (_selectedCountry != 'United Kingdom' &&
            docType == 'right to work') continue;

        final documentNumber =
            (doc['controller'] as TextEditingController).text.trim().isEmpty
                ? null
                : (doc['controller'] as TextEditingController).text.trim();

        final isDrivingLicense = docType == 'driving licence';
        final isTaxNo = docType == 'tax no';
        final isShareCode = docType == 'share code';

        if (!isDrivingLicense &&
            !isTaxNo &&
            !isShareCode &&
            (_files[i] == null || !(_files[i] as File).existsSync()) &&
            doc['file_url'] == null) {
          _showSnack('${doc['display_type']} file is required');
          setState(() => _isLoading = false);
          return;
        }

        validDocuments.add(OnboardingIdentityCheck(
          id: doc['id'],
          userId: widget.userId,
          documentType: docType,
          documentNumber: documentNumber,
          status: 'pending',
          created: DateTime.now().toIso8601String(),
          createdBy: widget.userId,
        ));

        if (!isTaxNo &&
            !isShareCode &&
            _files[i] != null &&
            (_files[i] as File).existsSync()) {
          validFiles.add(_files[i] as File);
        }

        if (!isDrivingLicense) hasAtLeastOneRequiredDocument = true;
      }

      if (!hasAtLeastOneRequiredDocument) {
        throw Exception('At least one required document is needed');
      }

      if (_isDocumentsSaved) {
        final updatedDocs = await _identityService.updateIdentityChecks(
            widget.userId, validDocuments, validFiles);
        setState(() {
          for (int i = 0; i < _documents.length; i++) {
            final updated = updatedDocs.firstWhere(
              (doc) => doc.documentType == _documents[i]['document_type'],
              orElse: () => OnboardingIdentityCheck(
                id: _documents[i]['id'],
                userId: widget.userId,
                documentType: _documents[i]['document_type'],
                documentNumber: _documents[i]['document_number'],
                status: 'pending',
                created: DateTime.now().toIso8601String(),
                createdBy: widget.userId,
              ),
            );
            _documents[i]['id'] = updated.id;
            _documents[i]['document_number'] = updated.documentNumber;
            _documents[i]['file_url'] = updated.fileUrl;
            (_documents[i]['controller'] as TextEditingController).text =
                updated.documentNumber ?? '';
            _documents[i]['file'] = null;
            _files[i] = null;
            _documents[i]['isExisting'] = true;
            _documents[i]['isEditing'] = false;
          }
        });
        _showSnack('Documents updated successfully');
      } else {
        await _identityService.createIdentityChecks(validDocuments, validFiles);
        await _fetchExistingDocuments();
        setState(() {
          _isDocumentsSaved = true;
          _animationController.forward();
        });
        widget.onDocumentsSaved?.call();
        _showSnack('Documents saved successfully');
      }

      widget.controller?.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
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

  String formatShareCode(String input) {
    final cleaned =
        input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length && i < 9; i++) {
      if (i == 3 || i == 6) buffer.write(' ');
      buffer.write(cleaned[i]);
    }
    return buffer.toString();
  }

  String? validateShareCode(String? value) {
    if (value == null || value.trim().isEmpty) return 'Share Code is required';
    final cleaned = value.replaceAll(' ', '');
    if (cleaned.length != 9) return 'Share Code must be 9 characters';
    if (!RegExp(r'^[A-Z0-9]{9}$').hasMatch(cleaned)) {
      return 'Invalid Share Code format';
    }
    return null;
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // ── No country fallback ───────────────────────────
                        if (_selectedCountry == null)
                          _buildSectionCard(
                            title: 'Country Not Found',
                            icon: Icons.warning_amber_outlined,
                            isSaved: false,
                            child: const Text(
                              'No country found. Please complete Personal Information first.',
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 14),
                            ),
                          ),

                        // ── One card per document ─────────────────────────
                        ..._documents.asMap().entries.map((entry) {
                          final index = entry.key;
                          final doc = entry.value;
                          return _buildDocumentCard(index, doc);
                        }),

                        const SizedBox(height: 32),

                        // ── Save / Update button ──────────────────────────
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
  // Document card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDocumentCard(int index, Map<String, dynamic> doc) {
    final docType = doc['document_type'] as String? ?? '';
    final displayType = doc['display_type'] as String? ?? '';
    final isTaxNo = docType == 'tax no';
    final isShareCode = docType == 'share code';
    final isDrivingLicense = docType == 'driving licence';
    final isExisting = doc['isExisting'] as bool? ?? false;
    final isEditing = doc['isEditing'] as bool? ?? true;
    final hasFile =
        doc['file'] != null || doc['file_url'] != null;
    final bool canUpload =
        !isTaxNo && (isEditing || !isExisting);

    final needsNumberField = [
      'National Insurance Number',
      'Social Insurance Number (SIN)',
      'Tax File Number (TFN)',
      'Work Permit',
    ].contains(displayType);
    final isShareCodeField = displayType == 'Share Code';

    final bool isSaved = isExisting && hasFile ||
        (isTaxNo && isExisting) ||
        (isShareCode && isExisting);

    final icon =
        _docTypeIcons[docType] ?? Icons.description_outlined;

    // File button label
    String fileButtonText;
    if (doc['file'] != null) {
      fileButtonText = (doc['file'] as File).path.split('/').last;
    } else if (doc['file_url'] != null) {
      fileButtonText =
          Uri.parse(doc['file_url'] as String).pathSegments.last;
    } else {
      fileButtonText = 'Upload File';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: _buildSectionCard(
        title: displayType,
        icon: icon,
        isSaved: isSaved,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── File upload row (not shown for tax number types) ──────────
            if (!isTaxNo && !isShareCode) ...[
              const Text(
                'Document File',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (canUpload) {
                          _pickFile(index);
                        } else if (doc['file_url'] != null) {
                          _viewFile(doc['file_url'] as String);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFFF6F6F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                              color: Color(0xFFFF6F6F), width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      icon: Icon(
                        hasFile
                            ? (canUpload
                                ? Icons.upload_file
                                : Icons.visibility)
                            : Icons.upload_file,
                        size: 18,
                        color: const Color(0xFFFF6F6F),
                      ),
                      label: Text(
                        fileButtonText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFFFF6F6F), fontSize: 13),
                      ),
                    ),
                  ),
                  if (isExisting && !isEditing)
                    IconButton(
                      icon: const Icon(Icons.edit,
                          color: Color(0xFFFF6F6F), size: 20),
                      onPressed: () =>
                          setState(() => doc['isEditing'] = true),
                    ),
                ],
              ),
              if (!isTaxNo &&
                  !isShareCode &&
                  !isDrivingLicense &&
                  !hasFile)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'File required',
                    style: TextStyle(
                        color: Colors.redAccent, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 8),
            ],

            // ── Number / code input fields ────────────────────────────────
            if (needsNumberField)
              _buildTextField(
                controller: doc['controller'],
                label: displayType,
                icon: Icons.document_scanner,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),

            if (isShareCodeField)
              _buildTextField(
                controller: doc['controller'],
                label: 'Share Code',
                icon: Icons.qr_code,
                keyboardType: TextInputType.text,
                validator: validateShareCode,
                onChanged: (value) {
                  final formatted = formatShareCode(value);
                  if (formatted != value) {
                    doc['controller'].value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                          offset: formatted.length),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared section card (same as skills & background pages)
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
                  color:
                      isSaved ? const Color(0xFFFF6F6F) : const Color(0xFFFF6F6F),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSaved
                          ? const Color(0xFFFF6F6F).withOpacity(0.9)
                          : Colors.black87,
                    ),
                  ),
                ),
                if (isSaved)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6F6F).withOpacity(0.1),
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
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
    Function()? onTap,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        onTap: onTap,
        onChanged: onChanged,
        validator: validator,
        decoration: _inputDecoration(label, icon),
        style: const TextStyle(color: Colors.black87, fontSize: 14),
      ),
    );
  }

  /// Full-width gradient Save / Update button.
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: (_isLoading || _selectedCountry == null)
          ? null
          : _saveOrUpdateDocuments,
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
          constraints: const BoxConstraints(
              minWidth: double.infinity, minHeight: 48),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: ThreeDotLoader(
                      color: Colors.white, size: 6),
                )
              : Text(
                  _isDocumentsSaved ? 'Update' : 'Save & Continue',
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
}