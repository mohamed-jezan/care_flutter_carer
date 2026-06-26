import 'package:call_care/widgets/three_dot_loader.dart';
import '../onboardingScreens/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import '../../service/auth_service.dart';
import '../mainScreens/HomeScreen.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../awaiting_verification_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final ApiService _apiService = ApiService();
  
  var token;

    @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkLoginStatus();
  });
  }

  Future<void> _checkLoginStatus() async {
  final token = await _apiService.getToken();

  /// ❌ No token → stay login
  if (token == null || JwtDecoder.isExpired(token)) {
    await _apiService.logout();
    return;
  }

  final userId = await _apiService.getUserId();
  final username = await _apiService.getUsername();
  final status = await _apiService.getStatus();
  // final forename = await _apiService.getForename();
  // final surname = await _apiService.getSurname();
  // final phone = await _apiService.getPhone();

  if (userId == null) return;

  /// ✅ Navigate
  if (status == "pending_onboarding") {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingPage(
          token: token,
          userId: userId,
          username: username ?? '',
        ),
      ),
    );
  } else if (status == "active") {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(
          
        ),
      ),
    );
  } else if (status == "awaiting_verification"){
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AwaitingVerificationPage(),
          ),
        );
      }
}

  /// ==================== HANDLE LOGIN ====================
Future<void> _handleLogin() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final response = await _apiService.login(
      email: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    print(response);

    if (response['success'] != true) {
      setState(() {
        _errorMessage = response['message'] ?? 'Login failed';
      });
      return;
    }

    final token = response['token'];
    final userId = response['user_id'];
    final username = response['username'];
    final role = response['role'];
    final status = response['status'];
    // final forename = response['forename'];
    // final surname = response['surname'];
    // final phone = response['phone'];

    if (role != 'Carer') {
      setState(() {
        _errorMessage =
            'This application is only accessible for Carer users.';
      });
      return;
    }

    if (token.isEmpty || userId.isEmpty) {
      setState(() {
        _errorMessage = "Invalid login response from server.";
      });
      return;
    }

    /// STATUS CHECK
    if (status == "pending_password") {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Password Reset Required"),
          content: const Text(
            "Please check your email and reset your password to continue.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }

    else if (status == "pending_onboarding") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OnboardingPage(
            token: token,
            userId: userId,
            username: username,
          ),
        ),
      );
    }

    else if (status == "active") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeScreen(
           
          ),
        ),
      );
    }

    else {
      setState(() {
        _errorMessage = "Unknown account status: $status";
      });
    }

  } catch (e) {
    setState(() {
      _errorMessage = e.toString();
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Wavy gradient background
          ClipPath(
            clipper: BottomCurveClipper(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6F6F), Color(0xFFFFA6A6)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const Image(
                    image: AssetImage('assets/images/logo_transperant.png'),
                    height: 120,
                  ),
                  const SizedBox(height: 20),
                  _buildLoginCard(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextField(
                  controller: _usernameController,
                  hint: "Enter email or username",
                  obscure: false,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _passwordController,
                  hint: "Password",
                  obscure: true,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage()),
                      );
                    },
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D4D),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const ThreeDotLoader(color: Colors.white)
                        : const Text(
                            'Log In',
                            style:
                                TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Create an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SignUpPage()),
                        );
                      },
                      child: const Text(
                        'Register',
                        style: TextStyle(color: Color(0xFFFF4D4D)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTabButton(String text, bool selected) {
    return ElevatedButton(
      onPressed: () {
        if (!selected && text == "Register") {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const SignUpPage()));
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? const Color(0xFFFF4D4D) : Colors.white,
        foregroundColor: selected ? Colors.white : Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: selected ? BorderSide.none : const BorderSide(color: Colors.grey),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
        elevation: 0,
      ),
      child: Text(text),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $hint';
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFFF4D4D)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

mixin userId {
}

class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(0, 0);
    path.lineTo(0, size.height - 30);
    path.arcToPoint(
      Offset(size.width, size.height - 80),
      radius: Radius.circular(size.width),
      clockwise: false,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
