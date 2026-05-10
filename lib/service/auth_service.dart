import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import '../screens/loginScreens/signin_page.dart';

class ApiService {
  static final String baseUrl = dotenv.env['BASE_URL'] ?? '';
  static final String whatsappUrl = '$baseUrl/whatsapp/send-otp';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? authToken;

  /* ===================== GLOBAL UNAUTHORIZED HANDLER ===================== */
  Future<void> handleUnauthorized(BuildContext context) async {
    await logout();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInPage()),
      (route) => false,
    );
  }

  /* ===================== COMMON AUTH HEADERS ===================== */
  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /* ===================== SIGNUP ===================== */
  Future<Map<String, dynamic>> signup({
    required String forename,
    required String surname,
    required String email,
    required String phone,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'forename': forename,
          'surname': surname,
          'username': email,
          'phone': phone,
          'status': 'pending_password',
          'created_by': email,
          'role_ids': ['9c15f453-288f-4e77-b159-d96aa905942b'],
        }),
      );

      final signupResponse = _handleResponse(response);
      if (signupResponse['success']) {
        final otpResponse = await sendOTP(phoneNumber: phone);
        
        if (otpResponse['success']) {
          return {
            "success": true,
            "message": 'Registration successful, OTP sent to ${phone}',
          };
        } else {
          return {
            "success": true, // Signup still succeeds, but OTP failed
            "message": 'Failed to send OTP: ${otpResponse['message']}',
          };
        }
      }

      return signupResponse;
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
    }
  }

  /* ===================== SEND OTP ===================== */
  Future<Map<String, dynamic>> sendOTP({
    required String phoneNumber,
  }) async {
    final url = Uri.parse(whatsappUrl);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "message": data['message']};
      }else {
        if (data['error']?['code'] == 190) {
          return {
            "success": false,
            "message": 'Bad signature (OAuthException 190): Token invalid or expired. Please update WhatsApp API token.',
          };
        }
        return {
          "success": false,
          "message": data['error']?['message'] ?? 'Failed to send OTP (Status: ${response.statusCode})',
        };
      }
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        return {"success": false, "message": "Network error: Please check your internet connection"};
      }
      return {"success": false, "message": "Error: $e"};
    }
  }

  /* ===================== VERIFY OTP ===================== */
  Future<Map<String, dynamic>> verifyOTP({
    required String phoneNumber,
    required String otp,
  }) async {
    final url = Uri.parse('$baseUrl/auth/verify-otp');

    try {
      final response = await http.post(
        url,
        headers: await _authHeaders(),
        body: jsonEncode({'phone': phoneNumber, 'otp': otp}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['token'] != null) {
          authToken = data['token'];
          await _storage.write(key: 'auth_token', value: authToken);
        }
        if (data['user_id'] != null) {
          await _storage.write(key: 'user_id', value: data['user_id']);
        }
        return {
          "success": true,
          "message": data['message'] ?? 'OTP verified successfully',
          "token": data['token'],
          "user_id": data['user_id'],
        };
      } else {
        return {
          "success": false,
          "message": data['message'] ?? 'OTP verification failed (Status: ${response.statusCode})',
        };
      }  
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  /* ===================== LOGIN ===================== */
 Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = data['token'];
        final userId = data['id'];
        final status = data['status'];

        // ✅ FIXED ROLES
        final roles = data['roles'] ?? [];
        final role = (roles is List && roles.isNotEmpty)
            ? roles[0].toString()
            : null;

        // ✅ FIXED TYPO
        final forename = data['forename'];
        final surname = data['surname'];
        final phone = data['phone'];

        // ROLE CHECK
        if (role != 'Carer') {
          return {
            "success": false,
            "message": "This application is only accessible for Carer users.",
          };
        }

        // SAVE DATA
        authToken = token;
        await _storage.write(key: 'auth_token', value: token);
        await _storage.write(key: 'user_id', value: userId);
        await _storage.write(key: 'username', value: email);
        await _storage.write(key: 'role', value: role);
        await _storage.write(key: 'status', value: status);
        await _storage.write(key: 'forename', value: forename);
        await _storage.write(key: 'surname', value: surname);
        await _storage.write(key: 'phone', value: phone);

        return {
          "success": true,
          "message": data['message'],
          "username": email,
          "token": token,
          "user_id": userId,
          "role": role,
          "status": status,
          "forename": forename,
          "surname": surname,
          "phone": phone,
        };
      } else {
        return {"success": false, "message": data['message']};
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  /* ===================== TOKEN ===================== */
  Future<String?> getToken() async {
    authToken ??= await _storage.read(key: 'auth_token');
    return authToken;
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: 'user_id');
  }

  Future<String?> getUsername() async {
    return await _storage.read(key: 'username');
  }

  Future<String?> getStatus() async {
    return await _storage.read(key: 'status');
  }

  Future<String?> getForename() async {
    return await _storage.read(key: 'forename');
  }

  Future<String?> getSurname() async {
    return await _storage.read(key: 'surname');
  }

  Future<String?> getPhone() async {
    return await _storage.read(key: 'phone');
  }

  /* ===================== VERIFY TOKEN ===================== */
  Future<bool> verifyToken() async {
    final url = Uri.parse('$baseUrl/auth/verify-token');

    try {
      final response = await http.post(
        url,
        headers: await _authHeaders(),
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /* ===================== GET USER PROFILE ===================== */
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final url = Uri.parse('$baseUrl/user/profile/$userId');

    try {
      final response = await http.get(
        url,
        headers: await _authHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  /* ===================== FORGOT PASSWORD ===================== */
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final url = Uri.parse('$baseUrl/auth/forgot-password');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': email}),
      );

      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  /* ===================== RESET PASSWORD ===================== */
  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final url = Uri.parse('$baseUrl/auth/reset-password?token=$token');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': newPassword}),
      );

      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  /* ===================== ROLE HELPERS ===================== */
  Future<String?> getRole() async {
    return await _storage.read(key: 'role');
  }

  Future<bool> isCarer() async => (await getRole()) == 'Carer';
  Future<bool> isAdmin() async => (await getRole()) == 'Admin';
  Future<bool> isClient() async => (await getRole()) == 'Client';


  /* ===================== LOGOUT ===================== */
  Future<void> logout() async {
    await _storage.deleteAll();
    authToken = null;
  }

  /* ===================== RESPONSE HANDLER ===================== */
  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {"success": true, ...data};
    }

    if (response.statusCode == 401) {
      return {
        "success": false, 
        "message": "Session expired",
        "unauthorized": true, 
        };
    }

    if (response.statusCode == 403) {
      return {"success": false, "message": "Access denied"};
    }

    return {
      "success": false,
      "message": data['message'] ?? 'Something went wrong',
    };
  }

  /* ===================== UPDATE USER STATUS ===================== */
Future<Map<String, dynamic>> updateUserStatus({
  required String userId,
  required String status,
}) async {
  final url = Uri.parse('$baseUrl/auth/update/$userId');

  try {
    final response = await http.put(
      url,
      headers: await _authHeaders(),
      body: jsonEncode({
        "status": status,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {
        "success": true,
        "message": data["message"] ?? "User status updated",
      };
    }

    return {
      "success": false,
      "message": data["message"] ?? "Failed to update status",
    };
  } catch (e) {
    return {"success": false, "message": e.toString()};
  }
}


}
