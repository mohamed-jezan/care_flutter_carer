import 'dart:async';
import 'package:call_care/widgets/three_dot_loader.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../model/onboarding_bank_details.dart';
import '../../service/onboarding_bank_details_service.dart';
import '../../service/auth_service.dart';
import '../awaiting_verification_page.dart';

class OnboardingBankDetailsPage extends StatefulWidget {
  final String token;
  final String userId;
  final String email;

  const OnboardingBankDetailsPage({
    Key? key,
    required this.token,
    required this.userId,
    required this.email,
  }) : super(key: key);

  @override
  State<OnboardingBankDetailsPage> createState() =>
      _OnboardingBankDetailsPageState();
}

class _OnboardingBankDetailsPageState extends State<OnboardingBankDetailsPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  OnboardingBankDetails? _bankDetails;
  late AnimationController _controller;
  late Animation<double> _fade;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    _fetchBankDetails();
  }

  Future<void> _submitOnboardingDetails() async {
  setState(() => _isLoading = true);

  try {
    final result = await _apiService.updateUserStatus(
      userId: widget.userId,
      status: "awaiting_verification",
    );

    if (result["success"] == true) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AwaitingVerificationPage(),
        ),
      );
    } else {
      _showMessage(result["message"]);
    }
  } catch (e) {
    _showMessage("Failed: $e");
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

 Future<void> _fetchBankDetails() async {
  setState(() => _isLoading = true);

  try {
    final service = OnboardingBankDetailsService(widget.token);

    final exists =
        await service.checkBankAccountExists(widget.userId);

    final details = exists
        ? await service.createExpressAccount(
            // existing account → backend returns existing DB info
            userId: widget.userId,
            email: widget.email,
            createdBy: widget.email,
          )
        : await service.createExpressAccount(
            // first time create
            userId: widget.userId,
            email: widget.email,
            createdBy: widget.email,
          );

    if (mounted) {
      setState(() {
        _bankDetails = details;
      });
    }
  } catch (e) {
    _showMessage("Failed to fetch bank details: $e");
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  Future<void> _launchStripe() async {
    if (_bankDetails == null) return;

    final url = Uri.parse(_bankDetails!.onboardingUrl);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);

    } catch (e) {
      _showMessage("Error launching Stripe URL: $e");
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  Widget _gradientButton(String text, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black26,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
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
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: ThreeDotLoader( color: Colors.white),
                )
              : Text(
                  text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white54, Colors.white10],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: _isLoading
                ? const Center(child: ThreeDotLoader(color: Colors.white))
                : _bankDetails == null
                    ? Center(
                        child: Text(
                          "Failed to load Stripe details",
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),

                            Icon(Icons.account_balance_wallet_rounded,
                                size: 100,
                                color: Colors.redAccent.withOpacity(0.85)),

                            const SizedBox(height: 30),

                            const Text(
                              "Connect Your Bank Account",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 28,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold),
                            ),

                            const SizedBox(height: 15),

                            const Text(
                              "Add your bank details securely via Stripe to receive your payments.",
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 16, color: Colors.black54),
                            ),

                            const SizedBox(height: 40),

                            /// Stripe Account ID Card
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    const Icon(Icons.credit_card,
                                        size: 32, color: Color(0xFF635BFF)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text("Your Stripe Account ID",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          Text(
                                            _bankDetails!.stripeAccountId,
                                            style: const TextStyle(
                                              fontFamily: "monospace",
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 20),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(
                                            text: _bankDetails!.stripeAccountId));
                                        _showMessage("Copied to clipboard");
                                      },
                                    )
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 50),

                            _gradientButton(
                                "Connect with Stripe", _launchStripe),

                            const SizedBox(height: 25),

                            const Text(
                              "You will be redirected to Stripe (secure & encrypted)\nSetup takes 2–5 minutes",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),

                            const SizedBox(height: 60),

                            _gradientButton(
                              "Submit Onboarding Details",
                              _submitOnboardingDetails,
                            ),

                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
