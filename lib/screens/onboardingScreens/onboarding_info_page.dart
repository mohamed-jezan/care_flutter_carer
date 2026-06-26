import 'package:call_care/widgets/three_dot_loader.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../model/onboarding_info.dart';
import '../../service/onboarding_info_service.dart';
import '../loginScreens/signin_page.dart';

class OnboardingInfoPage extends StatefulWidget {
  final String token;
  final String userId;
  final String username;
  final PageController? controller;
  final VoidCallback? onInfoSaved;
  final Function(String)? onCountrySelected;

  const OnboardingInfoPage({
    super.key,
    required this.token,
    required this.userId,
    required this.username,
    this.controller,
    this.onInfoSaved,
    this.onCountrySelected,
  });

  @override
  _OnboardingInfoPageState createState() => _OnboardingInfoPageState();
}

class _OnboardingInfoPageState extends State<OnboardingInfoPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final OnboardingInfoService _service;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _dobController = TextEditingController();
  final _genderController = TextEditingController();
  final _nationalityIdController = TextEditingController();
  final _postCodeController = TextEditingController();
  final _countryController = TextEditingController();
  final _emerContactNameController = TextEditingController();
  final _emerRelationshipController = TextEditingController();
  final _emerPhoneController = TextEditingController();
  final _maxMinutesController = TextEditingController();
  final _maxVisitsController = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _own_car = false;
  String? _infoId;
  String? _existingCreatedTimestamp;
  bool _isLoading = false;
  bool _isInfoSaved = false;

  late AnimationController _animationController;
  late Animation<double> fadeAnimation;

  // ── Address search ─────────────────────────────────────────────────────────
  List<Map<String, String>> _suggestions = [];
  bool _showSuggestions = false;
  bool _searching = false;
  String? selectedAddressId;
  String _selectedLine1 = '';
  String _selectedTown = '';

  // ── Nationality ────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _nationalities = [];
  String? _selectedNationalityName;

  // ── Constants ─────────────────────────────────────────────────────────────
  static const List<String> _addressCountries = [
    'United Kingdom',
    'Canada',
    'Australia',
    'Malaysia',
  ];
  final List<int> _maxMinutesOptions = [360, 420, 480, 540, 600];
  final List<int> _maxVisitsOptions = [5, 6, 7, 8, 9, 10];

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _service = OnboardingInfoService(widget.token);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _nationalityIdController.dispose();
    _postCodeController.dispose();
    _countryController.dispose();
    _emerContactNameController.dispose();
    _emerRelationshipController.dispose();
    _emerPhoneController.dispose();
    _maxMinutesController.dispose();
    _maxVisitsController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data & logic (unchanged from original)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      await _fetchNationalities();
      await _checkExistingInfo();
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _fetchNationalities() async {
    final nationalities = await _service.getCountries();
    setState(() => _nationalities = nationalities);
  }

  Future<void> _checkExistingInfo() async {
    try {
      final result =
          await _service.checkOnboardingInfoByUserId(widget.userId);
      if (result['exists'] && result['data'] != null) {
        final info = OnboardingInfo.fromJson(result['data']);
        setState(() {
          _infoId = info.id;
          _existingCreatedTimestamp = info.created;

          if (info.dob != null && info.dob!.isNotEmpty) {
            try {
              final parsed = DateTime.parse(info.dob!);
              _dobController.text = DateFormat('yyyy-MM-dd').format(parsed);
            } catch (_) {
              _dobController.text = info.dob!;
            }
          }

          _nationalityIdController.text =
              info.nationalityId?.toString() ?? '';
          _postCodeController.text = info.postCode ?? '';
          _countryController.text = info.country ?? '';
          _emerContactNameController.text = info.emerContactName ?? '';
          _emerRelationshipController.text = info.emerRelationship ?? '';
          _emerPhoneController.text = info.emerPhone ?? '';
          _maxMinutesController.text =
              info.maxMinutesPerDay?.toString() ?? '';
          _maxVisitsController.text = info.maxVisitsPerDay?.toString() ?? '';
          _own_car = info.ownCar ?? false;
          _selectedLine1 = info.street ?? '';
          _selectedTown = info.city ?? '';

          if (info.gender != null) {
            final g = info.gender!.toLowerCase();
            _genderController.text = g == 'male'
                ? 'Male'
                : g == 'female'
                    ? 'Female'
                    : g == 'other'
                        ? 'Other'
                        : '';
          }

          if (info.nationalityId != null && _nationalities.isNotEmpty) {
            final match = _nationalities.firstWhere(
              (c) => c['id'].toString() == info.nationalityId,
              orElse: () => {'id': '', 'name': ''},
            );
            _selectedNationalityName = match['name'] ?? '';
          }

          _isInfoSaved = true;
          _animationController.forward();
        });
      }
    } catch (e) {
      if (e.toString().contains('Unauthorized')) {
        _redirectToSignIn();
      } else {
        _showSnack('Error: $e');
      }
    }
  }

  Future<void> _searchPostcode() async {
    final pc = _postCodeController.text.trim();
    if (pc.isEmpty) {
      _showSnack('Enter a postcode');
      return;
    }
    setState(() {
      _searching = true;
      _showSuggestions = false;
      _suggestions = [];
    });
    try {
      final list = await _service.getAddressSuggestions(pc);
      setState(() {
        _suggestions = list;
        _showSuggestions = true;
      });
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => _searching = false);
    }
  }

  Future<void> _selectSuggestion(Map<String, String> item) async {
    setState(() => _showSuggestions = false);
    selectedAddressId = item['id'];
    try {
      final details = await _service.getAddressDetails(item['id']!);
      setState(() {
        _selectedLine1 = details['line_1']!;
        _selectedTown = details['town_or_city']!;
        _postCodeController.text = details['postcode']!;
      });
    } catch (e) {
      _showSnack('Failed to load details: $e');
    }
  }

  Future<void> _saveOrUpdateInfo() async {
    if (!_formKey.currentState!.validate()) return;

    if (_genderController.text.isNotEmpty &&
        !['Male', 'Female', 'Other'].contains(_genderController.text)) {
      _showSnack('Invalid gender value');
      return;
    }
    if (_selectedLine1.isEmpty) {
      _showSnack('Please select an address');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final info = OnboardingInfo(
        id: _infoId ?? '',
        userId: widget.userId,
        dob: _dobController.text.isEmpty ? null : _dobController.text,
        gender:
            _genderController.text.isEmpty ? null : _genderController.text,
        nationalityId: _nationalityIdController.text.isEmpty
            ? null
            : _nationalityIdController.text,
        street: _selectedLine1.isEmpty ? null : _selectedLine1,
        city: _selectedTown.isEmpty ? null : _selectedTown,
        postCode: _postCodeController.text.isEmpty
            ? null
            : _postCodeController.text,
        country: _countryController.text.isEmpty
            ? null
            : _countryController.text,
        emerContactName: _emerContactNameController.text.isEmpty
            ? null
            : _emerContactNameController.text,
        emerRelationship: _emerRelationshipController.text.isEmpty
            ? null
            : _emerRelationshipController.text,
        emerPhone: _emerPhoneController.text.isEmpty
            ? null
            : _emerPhoneController.text,
        maxMinutesPerDay: _maxMinutesController.text.isEmpty
            ? null
            : int.parse(_maxMinutesController.text),
        maxVisitsPerDay: _maxVisitsController.text.isEmpty
            ? null
            : int.parse(_maxVisitsController.text),
        ownCar: _own_car,
        createdBy: widget.username,
        created: _infoId == null
            ? DateTime.now().toIso8601String()
            : _existingCreatedTimestamp ?? DateTime.now().toIso8601String(),
        updatedBy: widget.username,
      );

      if (_infoId == null) {
        await _service.createOnboardingInfo(info);
        setState(() {
          _infoId = info.id;
          _existingCreatedTimestamp = info.created;
        });
        _showSnack('Personal info created successfully');
      } else {
        await _service.updateOnboardingInfo(widget.userId, info.toJson());
        _showSnack('Personal info updated successfully');
      }

      await _fetchNationalities();
      await _checkExistingInfo();

      setState(() => _isInfoSaved = true);
      widget.onInfoSaved?.call();

      if (widget.onCountrySelected != null &&
          _countryController.text.isNotEmpty) {
        widget.onCountrySelected!(_countryController.text);
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (c, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFF6F6F),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      _dobController.text = DateFormat('yyyy-MM-dd').format(date);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
                    color: Colors.white,
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

                        // ── Section 1: Personal Details ───────────────────
                        _buildSectionCard(
                          title: 'Personal Details',
                          icon: Icons.person_outline,
                          isSaved: _isInfoSaved &&
                              _dobController.text.isNotEmpty &&
                              _genderController.text.isNotEmpty &&
                              _selectedNationalityName != null,
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _dobController,
                                label: 'Date of Birth',
                                icon: Icons.calendar_today,
                                readOnly: true,
                                onTap: _pickDate,
                              ),
                              _buildDropdownField(
                                controller: _genderController,
                                label: 'Gender',
                                icon: Icons.wc,
                                items: ['Male', 'Female', 'Other'],
                              ),
                              _buildNationalityDropdown(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Section 2: Address ────────────────────────────
                        _buildSectionCard(
                          title: 'Address',
                          icon: Icons.home_outlined,
                          isSaved: _isInfoSaved && _selectedLine1.isNotEmpty,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Postcode search row
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _buildTextField(
                                      controller: _postCodeController,
                                      label: 'Postcode',
                                      icon: Icons.mail_outline,
                                      validator: (v) =>
                                          (v?.isEmpty ?? true)
                                              ? 'Required'
                                              : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _searching
                                          ? null
                                          : _searchPostcode,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFFF6F6F),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                      ),
                                      child: _searching
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: ThreeDotLoader(
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.search,
                                              color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),

                              // Address suggestions dropdown
                              if (_showSuggestions &&
                                  _suggestions.isNotEmpty)
                                Container(
                                  constraints:
                                      const BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _suggestions.length,
                                    itemBuilder: (ctx, i) {
                                      final item = _suggestions[i];
                                      return ListTile(
                                        dense: true,
                                        leading: const Icon(
                                          Icons.location_on_outlined,
                                          color: Color(0xFFFF6F6F),
                                          size: 18,
                                        ),
                                        title: Text(item['address']!,
                                            style: const TextStyle(
                                                fontSize: 13)),
                                        onTap: () =>
                                            _selectSuggestion(item),
                                      );
                                    },
                                  ),
                                ),

                              const SizedBox(height: 4),

                              // Selected address display
                              if (_selectedLine1.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        const Color(0xFFFF6F6F).withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFF6F6F)
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: Color(0xFFFF6F6F),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '$_selectedLine1\n$_selectedTown, ${_postCodeController.text}',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 13,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              _buildDropdownField(
                                controller: _countryController,
                                label: 'Country',
                                icon: Icons.flag_outlined,
                                items: _addressCountries,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Section 3: Emergency Contact ──────────────────
                        _buildSectionCard(
                          title: 'Emergency Contact',
                          icon: Icons.contact_emergency_outlined,
                          isSaved: _isInfoSaved &&
                              _emerContactNameController.text.isNotEmpty,
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _emerContactNameController,
                                label: 'Contact Name',
                                icon: Icons.person_outline,
                              ),
                              _buildTextField(
                                controller: _emerRelationshipController,
                                label: 'Relationship',
                                icon: Icons.family_restroom,
                              ),
                              _buildTextField(
                                controller: _emerPhoneController,
                                label: 'Phone Number',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (v) {
                                  if (v!.isEmpty) return 'Required';
                                  if (!RegExp(r'^\+?[1-9]\d{1,14}$')
                                      .hasMatch(v)) {
                                    return 'Enter a valid phone number';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Section 4: Work Preferences ───────────────────
                        _buildSectionCard(
                          title: 'Work Preferences',
                          icon: Icons.work_outline,
                          isSaved: _isInfoSaved &&
                              _maxMinutesController.text.isNotEmpty &&
                              _maxVisitsController.text.isNotEmpty,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDropdownFieldInt(
                                controller: _maxMinutesController,
                                label: 'Max Working Hours Per Day',
                                icon: Icons.access_time,
                                items: _maxMinutesOptions,
                                display: (v) => '${v ~/ 60} hours',
                              ),
                              _buildDropdownFieldInt(
                                controller: _maxVisitsController,
                                label: 'Max Visits Per Day',
                                icon: Icons.list_alt_outlined,
                                items: _maxVisitsOptions,
                                display: (v) => '$v visits',
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Do you have your own car?',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<bool>(
                                      value: true,
                                      groupValue: _own_car,
                                      onChanged: (v) =>
                                          setState(() => _own_car = v!),
                                      title: const Text('Yes',
                                          style: TextStyle(fontSize: 14)),
                                      activeColor: const Color(0xFFFF6F6F),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<bool>(
                                      value: false,
                                      groupValue: _own_car,
                                      onChanged: (v) =>
                                          setState(() => _own_car = v!),
                                      title: const Text('No',
                                          style: TextStyle(fontSize: 14)),
                                      activeColor: const Color(0xFFFF6F6F),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

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
  // Section card (identical pattern to all other onboarding pages)
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color:
                        isSaved ? const Color(0xFFFF6F6F) : Colors.black87,
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
  // Nationality searchable dropdown
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNationalityDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownSearch<String>(
        popupProps: const PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              hintText: 'Search countries...',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          menuProps: MenuProps(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        items: _nationalities.map((c) => c['name'] as String).toList(),
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration:
              _inputDecoration('Nationality', Icons.flag_outlined),
        ),
        onChanged: (String? newValue) {
          if (newValue != null) {
            final selected = _nationalities.firstWhere(
              (c) => c['name'] == newValue,
              orElse: () => {'id': '', 'name': ''},
            );
            _nationalityIdController.text = selected['id'].toString();
            _selectedNationalityName = newValue;
            if (_addressCountries.contains(newValue)) {
              _countryController.text = newValue;
            }
          }
        },
        selectedItem: _selectedNationalityName,
        validator: (v) => v == null ? 'Nationality is required' : null,
        filterFn: (item, filter) =>
            item.toLowerCase().contains(filter.toLowerCase()),
        dropdownBuilder: (context, selectedItem) => Text(
          selectedItem ?? '',
          style: const TextStyle(color: Colors.black87),
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
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        onTap: onTap,
        validator: validator ?? (v) => v!.isEmpty ? 'Required' : null,
        decoration: _inputDecoration(label, icon),
        style: const TextStyle(color: Colors.black87, fontSize: 14),
      ),
    );
  }

  Widget _buildDropdownField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<String> items,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: items.contains(controller.text) ? controller.text : null,
        decoration: _inputDecoration(label, icon),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: (v) => controller.text = v ?? '',
        validator: (v) => v == null ? 'Required' : null,
        style: const TextStyle(color: Colors.black87),
      ),
    );
  }

  Widget _buildDropdownFieldInt({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<int> items,
    required String Function(int) display,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<int>(
        value: controller.text.isNotEmpty
            ? int.tryParse(controller.text)
            : null,
        decoration: _inputDecoration(label, icon),
        items: items
            .map((i) =>
                DropdownMenuItem(value: i, child: Text(display(i))))
            .toList(),
        onChanged: (v) => controller.text = v?.toString() ?? '',
        validator: (v) => v == null ? 'Required' : null,
        style: const TextStyle(color: Colors.black87),
      ),
    );
  }

  /// Full-width gradient Save / Update button.
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveOrUpdateInfo,
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
                  _isInfoSaved ? 'Update' : 'Save & Continue',
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