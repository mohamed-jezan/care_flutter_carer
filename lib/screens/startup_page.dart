import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../service/auth_service.dart';
import 'loginScreens/signin_page.dart';
import '../widgets/three_dot_loader.dart';
import 'onboardingScreens/onboarding_page.dart';
import 'mainScreens/HomeScreen.dart';
import '../screens/awaiting_verification_page.dart';

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  final ApiService _apiService = ApiService();

  

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLogin();
    });
  }

  Future<void> _checkLogin() async {
    final token = await _apiService.getToken();

    /// ❌ No token OR expired → go login
    if (token == null || JwtDecoder.isExpired(token)) {
      await _apiService.logout();

      _goTo(const SignInPage());
      return;
    } 

    /// ✅ Get user data
    final userId = await _apiService.getUserId();
    final username = await _apiService.getUsername();
    final response = await _apiService.getUserProfile(userId!);
    // final forename = await _apiService.getForename();
    // final surname = await _apiService.getSurname();
    // final phone = await _apiService.getPhone();
    final status = response['status'];

    if (response['unauthorized'] == true) {
      await _apiService.logout();
      _goTo(const SignInPage());
      return;
    }

    /// Safety check
    if (status == null) {
      await _apiService.logout();
      _goTo(const SignInPage());
      return;
    }

    /// 🚀 STATUS BASED NAVIGATION
    if (status == "pending_password") {
      _goTo(const SignInPage());

    } else if (status == "pending_onboarding") {
      _goTo(
        OnboardingPage(
          token: token,
          userId: userId,
          username: username ?? '',
        ),
      );

    } else if (status == "active") {
      _goTo(
        HomeScreen(
          
        ),
      );

    } else if (status == "awaiting_verification"){
      _goTo(
        AwaitingVerificationPage(),
      );
    }else {
      _goTo(const SignInPage());
    }
  }

  /// ✅ Clean navigation helper
  void _goTo(Widget page) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: const [
      const ThreeDotLoader(),
      SizedBox(height: 16),
    ],
  ),
),
    );
  }
}

