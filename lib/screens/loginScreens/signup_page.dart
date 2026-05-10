import 'package:call_care/widgets/three_dot_loader.dart';
import 'package:flutter/material.dart';
import 'signin_page.dart';
import '../../service/auth_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _forenameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController(); // New OTP field
  bool _isLoading = false;
  String? _errorMessage;
  bool _showOtpField = false; // Toggle OTP field visibility

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate() && !_showOtpField) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final apiService = ApiService();
        final otpResponse = await apiService.sendOTP(
          phoneNumber: _phoneController.text.trim()
        );
        print("OTP Send Response: $otpResponse");

         if (otpResponse['success'] == true) {
          setState(() {
            _showOtpField = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(otpResponse['message'] ?? 'OTP sent to ${_phoneController.text.trim()}')),
          );
        } else {
          setState(() {
            _errorMessage = otpResponse['message'];
            _isLoading = false;
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
  }

  Future<void> _handleVerifyAndRegister() async {
    if (_formKey.currentState!.validate() && _showOtpField) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final apiService = ApiService();
        final verifyResponse = await apiService.verifyOTP(
          phoneNumber: _phoneController.text.trim(),
          otp: _otpController.text.trim(),
        );
        print("Verify OTP Response: $verifyResponse");

        if (verifyResponse['success']) {
          final signupResponse = await apiService.signup(
            forename: _forenameController.text.trim(),
            surname: _surnameController.text.trim(),
            email: _usernameController.text.trim(),
            phone: _phoneController.text.trim(),
          );
          print("Signup Response: $signupResponse");

          if (signupResponse['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(signupResponse['message'] ?? 'Registration successful')),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SignInPage()),
            );
          } else {
            setState(() {
              _errorMessage = signupResponse['message'];
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _errorMessage = verifyResponse['message'];
            _isLoading = false;
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
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
                  _buildSignUpCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          )
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
                  controller: _forenameController,
                  hint: "Forename",
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _surnameController,
                  hint: "Surname",
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _usernameController,
                  hint: "Email",
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneController,
                  hint: "Phone Number",
                  keyboardType: TextInputType.phone,
                ),
                if (_showOtpField) ...[
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _otpController,
                    hint: "Enter OTP",
                    keyboardType: TextInputType.number,
                  ),
                ],
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
                    onPressed: _isLoading
                        ? null
                        : (_showOtpField ? _handleVerifyAndRegister : _handleRegister),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D4D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const ThreeDotLoader(color: Colors.white)
                        : Text(
                            _showOtpField ? 'Verify and Register' : 'Send OTP',
                            style: const TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignInPage()),
                        );
                      },
                      child: const Text(
                        'Log In',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $hint';
        }
        if (hint == "Email" && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        if (hint == "Phone Number (e.g., +94712345678)" &&
            !RegExp(r'^\+\d{10,12}$').hasMatch(value)) {
          return 'Please enter a valid phone number with country code (e.g., +94712345678)';
        }
        if (hint == "Enter OTP" && !RegExp(r'^\d{4,6}$').hasMatch(value)) {
          return 'Please enter a valid OTP (4-6 digits)';
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
    _forenameController.dispose();
    _surnameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
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