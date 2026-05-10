import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/onboarding_info.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OnboardingInfoService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? '';
  final String token;

  OnboardingInfoService(this.token);

  Future<OnboardingInfo> createOnboardingInfo(OnboardingInfo info) async {
    final response = await http.post(
      Uri.parse('$baseUrl/carer/info/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(info.toJson()),
    );

    if (response.statusCode == 201) {
      return OnboardingInfo.fromJson(jsonDecode(response.body)['data']);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    } else {
      throw Exception('Failed to create carer info: ${response.body}');
    }
  }

  Future<OnboardingInfo> getOnboardingInfoById(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/carer/info/get/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return OnboardingInfo.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    } else {
      throw Exception('Failed to fetch carer info: ${response.body}');
    }
  }

  Future<List<OnboardingInfo>> getAllOnboardingInfo() async {
    final response = await http.get(
      Uri.parse('$baseUrl/carer/info/all'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => OnboardingInfo.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    } else {
      throw Exception('Failed to fetch all carer info: ${response.body}');
    }
  }

  Future<OnboardingInfo> updateOnboardingInfo(String userId, Map<String, dynamic> updates) async {
    final response = await http.put(
      Uri.parse('$baseUrl/carer/info/update/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(updates),
    );

    if (response.statusCode == 200) {
      return OnboardingInfo.fromJson(jsonDecode(response.body)['data']);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    } else {
      throw Exception('Failed to update carer info: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> checkOnboardingInfoByUserId(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/carer/info/check/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'exists': data['exists'] ?? false,
        'data': data['data'],
      };
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    } else {
      throw Exception('Failed to check carer personal info: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getCountries() async {
    final response = await http.get(
      Uri.parse('$baseUrl/country/all'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => json as Map<String, dynamic>).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    } else {
      throw Exception('Failed to fetch all carer country info: ${response.body}');
    }
  }

  // NEW – autocomplete by postcode
  Future<List<Map<String, String>>> getAddressSuggestions(String postcode) async {
    final uri = Uri.parse('$baseUrl/address/autocomplete').replace(
      queryParameters: {'postcode': postcode},
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] != true) throw Exception('API error');
      final List<dynamic> list = json['suggestions'];
      return list
          .map((e) => {
                'id': e['id'] as String,
                'address': e['address'] as String,
              })
          .toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    } else {
      throw Exception('Failed to fetch suggestions: ${response.body}');
    }
  }

  // NEW – address details by id
  Future<Map<String, String>> getAddressDetails(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/address/details/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] != true) throw Exception('API error');
      final addr = json['address'] as Map<String, dynamic>;
      return {
        'line_1': addr['line_1'] as String,
        'postcode': addr['postcode'] as String,
        'town_or_city': addr['town_or_city'] as String,
      };
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    } else {
      throw Exception('Failed to fetch address details: ${response.body}');
    }
  }
}