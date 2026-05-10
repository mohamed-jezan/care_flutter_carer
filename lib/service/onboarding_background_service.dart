import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:retry/retry.dart';
import '../model/onboarding_background.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OnboardingBackgroundService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? '';
  final String token;

  OnboardingBackgroundService(this.token);

  Future<OnboardingBackground?> createBackgroundCheck({
    required String userId,
    required int yearsExperience,
    required List<PreviousJob> previousJobs,
    required List<Reference> references,
    required List<Qualification> qualifications,
    required List<String> specialistTraining,
    required List<String> mandatoryTraining,
    required String dbsCertificateNumber,
    required String dbsIssueDate,
    required File dbsCertificateFile,
    File? cvFile,
    List<File> qualificationFiles = const [],
    bool? wwcc,
    String? createdBy,
  }) async {
    try {
      return await retry(
        () async {
          var request = http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/carer/background/create'),
          );
          request.headers['Authorization'] = 'Bearer $token';

          request.fields['user_id'] = userId;
          request.fields['years_experience'] = yearsExperience.toString();

          // Field names must match parseArrayField keys in controller
          request.fields['previousJobs'] =
              jsonEncode(previousJobs.map((job) => job.toJson()).toList());
          // Controller reads 'carerReferences'
          request.fields['carerReferences'] =
              jsonEncode(references.map((ref) => ref.toJson()).toList());
          // Controller reads 'qualificationsData'
          request.fields['qualificationsData'] =
              jsonEncode(qualifications.map((qual) => qual.toJson()).toList());
          // Training sent as plain string arrays
          request.fields['specialistTraining'] = jsonEncode(specialistTraining);
          request.fields['mandatoryTraining'] = jsonEncode(mandatoryTraining);

          request.fields['dbs_certificate_number'] = dbsCertificateNumber;
          request.fields['dbs_issue_date'] = dbsIssueDate;
          if (wwcc != null) request.fields['wwcc'] = wwcc.toString();
          if (createdBy != null) request.fields['created_by'] = createdBy;

          // DBS file field name: 'dbs_certificate'
          final dbsMimeType = lookupMimeType(dbsCertificateFile.path);
          request.files.add(await http.MultipartFile.fromPath(
            'dbs_certificate',
            dbsCertificateFile.path,
            contentType:
                dbsMimeType != null ? MediaType.parse(dbsMimeType) : null,
          ));

          // CV file field name: 'cv'
          if (cvFile != null) {
            final cvMimeType = lookupMimeType(cvFile.path);
            request.files.add(await http.MultipartFile.fromPath(
              'cv',
              cvFile.path,
              contentType:
                  cvMimeType != null ? MediaType.parse(cvMimeType) : null,
            ));
          }

          // Qualification files field name: 'qualificationsFiles'
          for (var file in qualificationFiles) {
            final qualMimeType = lookupMimeType(file.path);
            request.files.add(await http.MultipartFile.fromPath(
              'qualificationsFiles',
              file.path,
              contentType:
                  qualMimeType != null ? MediaType.parse(qualMimeType) : null,
            ));
          }

          final response = await request.send();
          final responseBody = await response.stream.bytesToString();

          if (response.statusCode == 201) {
            final json = jsonDecode(responseBody);
            return OnboardingBackground.fromJson(json['data']);
          } else {
            final errorJson = jsonDecode(responseBody);
            throw Exception(
                'Failed to create background check: ${errorJson['message'] ?? responseBody}');
          }
        },
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 2),
        randomizationFactor: 0.25,
        onRetry: (e) => print('Retrying create due to: $e'),
      );
    } catch (e) {
      throw Exception('Error creating background check: $e');
    }
  }

  Future<OnboardingBackground?> updateBackgroundCheck({
    required String userId,
    required int yearsExperience,
    required List<PreviousJob> previousJobs,
    required List<Reference> references,
    required List<Qualification> qualifications,
    required List<String> specialistTraining,
    required List<String> mandatoryTraining,
    required String dbsCertificateNumber,
    required String dbsIssueDate,
    File? dbsCertificateFile,
    File? cvFile,
    List<File> qualificationFiles = const [],
    bool? wwcc,
    String? updatedBy,
  }) async {
    try {
      return await retry(
        () async {
          var request = http.MultipartRequest(
            'PUT',
            Uri.parse('$baseUrl/carer/background/update/$userId'),
          );
          request.headers['Authorization'] = 'Bearer $token';

          request.fields['user_id'] = userId;
          request.fields['years_experience'] = yearsExperience.toString();

          request.fields['previousJobs'] =
              jsonEncode(previousJobs.map((job) => job.toJson()).toList());
          request.fields['carerReferences'] =
              jsonEncode(references.map((ref) => ref.toJson()).toList());
          request.fields['qualificationsData'] =
              jsonEncode(qualifications.map((qual) => qual.toJson()).toList());
          request.fields['specialistTraining'] = jsonEncode(specialistTraining);
          request.fields['mandatoryTraining'] = jsonEncode(mandatoryTraining);

          request.fields['dbs_certificate_number'] = dbsCertificateNumber;
          request.fields['dbs_issue_date'] = dbsIssueDate;
          if (wwcc != null) request.fields['wwcc'] = wwcc.toString();
          if (updatedBy != null) request.fields['updated_by'] = updatedBy;

          if (dbsCertificateFile != null) {
            final dbsMimeType = lookupMimeType(dbsCertificateFile.path);
            request.files.add(await http.MultipartFile.fromPath(
              'dbs_certificate',
              dbsCertificateFile.path,
              contentType:
                  dbsMimeType != null ? MediaType.parse(dbsMimeType) : null,
            ));
          }

          if (cvFile != null) {
            final cvMimeType = lookupMimeType(cvFile.path);
            request.files.add(await http.MultipartFile.fromPath(
              'cv',
              cvFile.path,
              contentType:
                  cvMimeType != null ? MediaType.parse(cvMimeType) : null,
            ));
          }

          for (var file in qualificationFiles) {
            final qualMimeType = lookupMimeType(file.path);
            request.files.add(await http.MultipartFile.fromPath(
              'qualificationsFiles',
              file.path,
              contentType:
                  qualMimeType != null ? MediaType.parse(qualMimeType) : null,
            ));
          }

          final response = await request.send();
          final responseBody = await response.stream.bytesToString();

          if (response.statusCode == 200) {
            final json = jsonDecode(responseBody);
            return OnboardingBackground.fromJson(json['data']);
          } else {
            final errorJson = jsonDecode(responseBody);
            throw Exception(
                'Failed to update background check: ${errorJson['message'] ?? responseBody}');
          }
        },
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 2),
        randomizationFactor: 0.25,
        onRetry: (e) => print('Retrying update due to: $e'),
      );
    } catch (e) {
      throw Exception('Error updating background check: $e');
    }
  }

  Future<List<OnboardingBackground>> getBackgroundChecksByUserId(
      String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/carer/background/get_by_user/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return (json as List<dynamic>)
            .map((item) => OnboardingBackground.fromJson(item))
            .toList();
      } else {
        final errorJson = jsonDecode(response.body);
        throw Exception(
            'Failed to fetch background checks: ${errorJson['error'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching background checks: $e');
    }
  }

  Future<void> deleteBackgroundCheckByUserId(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/carer/background/delete/by_user/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        final errorJson = jsonDecode(response.body);
        throw Exception(
            'Failed to delete background check: ${errorJson['message'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting background check: $e');
    }
  }
}