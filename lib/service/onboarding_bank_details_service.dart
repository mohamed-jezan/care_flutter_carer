import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../model/onboarding_bank_details.dart';

class OnboardingBankDetailsService {
  final String token;
  final String baseUrl = dotenv.env['BASE_URL'] ?? '';

  OnboardingBankDetailsService(this.token);

  Future<OnboardingBankDetails> createExpressAccount({
    required String userId,
    required String email,
    String? createdBy,
  }) async {
    final url = Uri.parse('$baseUrl/stripe/create-express-account');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'user_id': userId,
        'email': email,
        'createdBy': createdBy,
      }),
    );

    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return OnboardingBankDetails.fromJson(json);
    } else if (response.statusCode == 400) {
      throw Exception('Missing user_id or email');
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to create Stripe account');
    }
  }

  Future<bool> checkBankAccountExists(String userId) async {
  final response = await http.get(
    Uri.parse(
      "$baseUrl/get/status/$userId",
    ),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    return data["exists"] != false;
  }

  return false;
}
}