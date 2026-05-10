// lib/service/onboarding_skills_service.dart
//
// Talks to four separate backend resources:
//   /carer/skills/*        — carer_skills table (one row per skill)
//   /carer/language/*      — carer_languages table (one row per language)
//   /carer/preferences/*   — carer_preferences table (one row per user)
//   /carer/availability/*  — carer_availability table (one row per slot)

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../model/carer_skill.dart';
import '../model/carer_language.dart';
import '../model/carer_preference.dart';
import '../model/carer_availability.dart';

class OnboardingSkillsService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? '';
  final String token;

  OnboardingSkillsService(this.token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  void _checkUnauthorized(http.Response res) {
    if (res.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // REFERENCE LANGUAGES  —  GET /language/all
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, String>>> getAllLanguages() async {
    final res = await http.get(
      Uri.parse('$baseUrl/language/all'),
      headers: _headers,
    );
    _checkUnauthorized(res);
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.map<Map<String, String>>((e) => {
            'id': e['id']?.toString() ?? '',
            'langEN': e['langEN']?.toString() ?? '',
          }).toList();
    }
    throw Exception('Failed to fetch languages: ${res.body}');
  }

  // ═════════════════════════════════════════════════════════════════════════
  // CARER SKILLS  —  /carer/skills/*
  // ═════════════════════════════════════════════════════════════════════════

  /// GET /carer/skills/check/:user_id
  Future<({bool exists, List<CarerSkill> rows})> checkCarerSkillsByUserId(
      String userId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/carer/skills/check/$userId'),
      headers: _headers,
    );
    _checkUnauthorized(res);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final exists = body['exists'] == true;
      final data = body['data'];
      final rows = <CarerSkill>[];
      if (exists && data is List) {
        rows.addAll(
            data.map((e) => CarerSkill.fromJson(e as Map<String, dynamic>)));
      }
      return (exists: exists, rows: rows);
    }
    throw Exception('Failed to check carer skills: ${res.body}');
  }

  Future<void> _deleteSkillRow(String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/carer/skills/$id'),
      headers: _headers,
    );
    _checkUnauthorized(res);
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete skill row $id: ${res.body}');
    }
  }

  /// POST /carer/skills/bulk-create
  /// Payload: { user_id, skills: [...], created_by, status }
  Future<void> _bulkCreateSkills({
    required String userId,
    required List<String> skillNames,
    required String createdBy,
  }) async {
    if (skillNames.isEmpty) return;
    final res = await http.post(
      Uri.parse('$baseUrl/carer/skills/bulk-create'),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'skills': skillNames,
        'created_by': createdBy,
        'status': 'pending',
      }),
    );
    _checkUnauthorized(res);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to bulk-create skills: ${res.body}');
    }
  }

  Future<void> saveSkills({
    required String userId,
    required List<String> skillNames,
    required String createdBy,
    required List<CarerSkill> existingRows,
  }) async {
    for (final row in existingRows) {
      if (row.id.isNotEmpty) await _deleteSkillRow(row.id);
    }
    await _bulkCreateSkills(
        userId: userId, skillNames: skillNames, createdBy: createdBy);
  }

  // ═════════════════════════════════════════════════════════════════════════
// CARER LANGUAGES  —  /carer/language/*
// Primary = create
// Others  = bulk-create
// ═════════════════════════════════════════════════════════════════════════

Future<({bool exists, List<CarerLanguage> rows})>
    checkCarerLanguagesByUserId(String userId) async {
  final res = await http.get(
    Uri.parse('$baseUrl/carer/language/check/$userId'),
    headers: _headers,
  );

  _checkUnauthorized(res);

  if (res.statusCode == 200) {
    final body = jsonDecode(res.body);

    final exists = body['exists'] == true;
    final rows = <CarerLanguage>[];

    if (exists && body['data'] != null) {
      rows.addAll(
        (body['data'] as List)
            .map((e) => CarerLanguage.fromJson(e)),
      );
    }

    return (exists: exists, rows: rows);
  }

  throw Exception('Failed to check languages');
}

Future<void> _deleteLanguageRow(String id) async {
  final res = await http.delete(
    Uri.parse('$baseUrl/carer/language/$id'),
    headers: _headers,
  );

  _checkUnauthorized(res);

  if (res.statusCode != 200 &&
      res.statusCode != 204) {
    throw Exception('Failed deleting language');
  }
}


// PRIMARY LANGUAGE
Future<void> _createPrimaryLanguage({
  required String userId,
  required int languageId,
  required String createdBy,
}) async {

  final res = await http.post(
    Uri.parse('$baseUrl/carer/language/create'),
    headers: _headers,
    body: jsonEncode({
      "user_id": userId,
      "language_id": languageId,
      "is_primary": true,
      "created_by": createdBy,
      "status": "pending",
    }),
  );

  _checkUnauthorized(res);

  if (res.statusCode != 200 &&
      res.statusCode != 201) {
    throw Exception(
      'Failed creating primary language: ${res.body}',
    );
  }
}


// OTHER LANGUAGES
Future<void> _bulkCreateOtherLanguages({
  required String userId,
  required List<int> languageIds,
  required String createdBy,
}) async {

  if (languageIds.isEmpty) return;

  final res = await http.post(
    Uri.parse('$baseUrl/carer/language/bulk-create'),
    headers: _headers,
    body: jsonEncode({
      "user_id": userId,
      "language_id": languageIds,
      "is_primary": false,
      "created_by": createdBy,
      "status": "pending",
    }),
  );

  _checkUnauthorized(res);

  if (res.statusCode != 200 &&
      res.statusCode != 201) {
    throw Exception(
      'Failed bulk-create languages: ${res.body}',
    );
  }
}


Future<void> saveLanguages({
  required String userId,
  required int primaryLanguageId,
  required List<int> otherLanguageIds,
  required String createdBy,
  required List<CarerLanguage> existingRows,
}) async {

  // delete old rows
  for (final row in existingRows) {
    if (row.id.isNotEmpty) {
      await _deleteLanguageRow(row.id);
    }
  }

  // create primary
  await _createPrimaryLanguage(
    userId: userId,
    languageId: primaryLanguageId,
    createdBy: createdBy,
  );

  // bulk create others
  await _bulkCreateOtherLanguages(
    userId: userId,
    languageIds: otherLanguageIds,
    createdBy: createdBy,
  );
}

  // ═════════════════════════════════════════════════════════════════════════
  // CARER PREFERENCES  —  /carer/preferences/*
  // ═════════════════════════════════════════════════════════════════════════

  /// GET /carer/preferences/check/:user_id
  Future<({bool exists, CarerPreference? preference})>
      checkCarerPreferenceByUserId(String userId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/carer/preferences/check/$userId'),
      headers: _headers,
    );
    _checkUnauthorized(res);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final exists = body['exists'] == true;
      if (!exists || body['data'] == null) {
        return (exists: false, preference: null);
      }
      final raw = body['data'];
      final prefMap = raw is List
          ? (raw.isNotEmpty ? raw.first as Map<String, dynamic> : null)
          : raw as Map<String, dynamic>?;
      if (prefMap == null) return (exists: false, preference: null);
      return (exists: true, preference: CarerPreference.fromJson(prefMap));
    }
    throw Exception('Failed to check carer preferences: ${res.body}');
  }

  Future<CarerPreference> _createPreference({
    required String userId,
    required String preferredClientGender,
    required String partTimePreference,
    required String createdBy,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/carer/preferences/create'),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'preferred_client_gender': preferredClientGender,
        'part_time_preference': partTimePreference,
        'status': 'pending',
        'created_by': createdBy,
      }),
    );
    _checkUnauthorized(res);
    if (res.statusCode == 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] ?? body;
      return CarerPreference.fromJson(data as Map<String, dynamic>);
    }
    throw Exception('Failed to create carer preference: ${res.body}');
  }

  Future<void> _updatePreference({
    required String userId,
    required String preferredClientGender,
    required String partTimePreference,
    required String updatedBy,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/carer/preferences/update/$userId'),
      headers: _headers,
      body: jsonEncode({
        'preferred_client_gender': preferredClientGender,
        'part_time_preference': partTimePreference,
        'updated_by': updatedBy,
      }),
    );
    _checkUnauthorized(res);
    if (res.statusCode != 200) {
      throw Exception('Failed to update carer preference: ${res.body}');
    }
  }

  Future<String> savePreference({
    required String userId,
    required String? existingPreferenceId,
    required String preferredClientGender,
    required String partTimePreference,
    required String createdOrUpdatedBy,
  }) async {
    if (existingPreferenceId == null || existingPreferenceId.isEmpty) {
      final created = await _createPreference(
        userId: userId,
        preferredClientGender: preferredClientGender,
        partTimePreference: partTimePreference,
        createdBy: createdOrUpdatedBy,
      );
      return created.id;
    } else {
      await _updatePreference(
        userId: userId,
        preferredClientGender: preferredClientGender,
        partTimePreference: partTimePreference,
        updatedBy: createdOrUpdatedBy,
      );
      return existingPreferenceId;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // CARER AVAILABILITY  —  /carer/availability/*
  // ═════════════════════════════════════════════════════════════════════════

  /// GET /carer/availability/check/:user_id
  Future<({bool exists, List<CarerAvailability> rows})>
      checkCarerAvailabilityByUserId(String userId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/carer/availability/check/$userId'),
      headers: _headers,
    );
    _checkUnauthorized(res);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final exists = body['exists'] == true;
      final data = body['data'];
      final rows = <CarerAvailability>[];
      if (exists && data is List) {
        rows.addAll(data.map(
            (e) => CarerAvailability.fromJson(e as Map<String, dynamic>)));
      }
      return (exists: exists, rows: rows);
    }
    throw Exception('Failed to check carer availability: ${res.body}');
  }

  /// POST /carer/availability/bulk-create
  ///
  /// Backend expects:
  /// {
  ///   "user_id": "...",
  ///   "created_by": "...",
  ///   "availabilities": [
  ///     {
  ///       "availability_type": "recurring",
  ///       "day_of_week": 1,
  ///       "start_time": "09:00",
  ///       "end_time": "17:00",
  ///       "is_available": true,
  ///       "status": "pending"
  ///     }
  ///   ]
  /// }
  Future<void> bulkCreateAvailability({
    required String userId,
    required List<CarerAvailability> slots,
    required String createdBy,
  }) async {
    if (slots.isEmpty) return;

    final payload = {
      'user_id': userId,
      'created_by': createdBy,
      'availabilities': slots.map((s) => s.toBulkCreateItem()).toList(),
    };

    final res = await http.post(
      Uri.parse('$baseUrl/carer/availability/bulk-create'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    _checkUnauthorized(res);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to bulk-create availability: ${res.body}');
    }
  }

  /// PUT /carer/availability/update/:id
  Future<void> updateAvailabilityRow({
    required String id,
    required CarerAvailability slot,
    required String updatedBy,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/carer/availability/update/$id'),
      headers: _headers,
      body: jsonEncode(slot.toUpdateJson(updatedBy: updatedBy)),
    );
    _checkUnauthorized(res);
    if (res.statusCode != 200) {
      throw Exception('Failed to update availability row $id: ${res.body}');
    }
  }

  /// DELETE /carer/availability/:id
  Future<void> deleteAvailabilityRow(String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/carer/availability/$id'),
      headers: _headers,
    );
    _checkUnauthorized(res);
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete availability row $id: ${res.body}');
    }
  }

  /// Deletes all existing availability rows then bulk-creates the new set.
  Future<void> saveAvailability({
    required String userId,
    required List<CarerAvailability> slots,
    required String createdBy,
    required List<CarerAvailability> existingRows,
  }) async {
    for (final row in existingRows) {
      if (row.id.isNotEmpty) await deleteAvailabilityRow(row.id);
    }
    await bulkCreateAvailability(
        userId: userId, slots: slots, createdBy: createdBy);
  }
}