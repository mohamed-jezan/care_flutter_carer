import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../model/onboarding_identity_check.dart';

class OnboardingIdentityCheckService {

  final String token;

  final String baseUrl =
      dotenv.env['BASE_URL'] ?? "";

  OnboardingIdentityCheckService(
    this.token,
  );

  Map<String,String> get headers => {
        "Authorization":"Bearer $token",
        "Content-Type":"application/json"
      };


//================================
// GET BY USER
//================================

  Future<List<OnboardingIdentityCheck>>
      getIdentityChecksByUserId(
    String userId,
  ) async {

    final response = await http.get(
      Uri.parse(
        "$baseUrl/carer/identity/get_by_user/$userId",
      ),
      headers: headers,
    );

    if(response.statusCode==200){

      final List data =
          jsonDecode(response.body);

      return data
          .map(
            (e)=>OnboardingIdentityCheck
                .fromJson(e),
          )
          .toList();
    }

    throw Exception(response.body);
  }



//================================
// CREATE
//================================

  Future<void> createIdentityChecks(
    List<OnboardingIdentityCheck> docs,
    List<File> files,
  ) async {

    final request =
        http.MultipartRequest(
      "POST",
      Uri.parse(
        "$baseUrl/carer/identity/create",
      ),
    );

    request.headers.addAll({
      "Authorization":"Bearer $token"
    });

    request.fields["user_id"] =
        docs.first.userId;

    request.fields["created_by"] =
        docs.first.createdBy ?? "";

    request.fields["documents"] =
        jsonEncode(
      docs.map(
        (e)=>{

          "document_type":
              e.documentType,

          "document_number":
              e.documentNumber,
        },
      ).toList(),
    );

    for(final file in files){

      request.files.add(
        await http.MultipartFile
            .fromPath(
          "files",
          file.path,
          contentType:
              MediaType(
            "application",
            "octet-stream",
          ),
        ),
      );
    }

    final response =
        await request.send();

    if(response.statusCode!=201){

      throw Exception(
        await response.stream
            .bytesToString(),
      );
    }
  }



//================================
// BULK UPDATE
//================================

  Future<List<OnboardingIdentityCheck>>
      updateIdentityChecks(
    String userId,
    List<OnboardingIdentityCheck> docs,
    List<File> files,
  ) async {

    final request =
        http.MultipartRequest(
      "PUT",
      Uri.parse(
        "$baseUrl/carer/identity/update/$userId",
      ),
    );

    request.headers.addAll({
      "Authorization":"Bearer $token"
    });

    request.fields["documents"] =
        jsonEncode(
      docs.map(
        (e)=>{

          "id":e.id,

          "document_type":
              e.documentType,

          "document_number":
              e.documentNumber,

          "status":
              e.status,

          "updated_by":
              e.userId,
        },
      ).toList(),
    );

    for(final file in files){

      request.files.add(
        await http.MultipartFile
            .fromPath(
          "files",
          file.path,
          contentType:
              MediaType(
            "application",
            "octet-stream",
          ),
        ),
      );
    }

    final response =
        await request.send();

    final body =
        await response.stream
            .bytesToString();

    if(response.statusCode==200){

      final List data =
          jsonDecode(body)["data"];

      return data
          .map(
            (e)=>
                OnboardingIdentityCheck
                    .fromJson(e),
          )
          .toList();
    }

    throw Exception(body);
  }



//================================
// SINGLE UPDATE
//================================

  Future<void> updateById({
    required String id,
    required String status,
    String? reason,
  }) async {

    final response =
        await http.put(

      Uri.parse(
        "$baseUrl/carer/identity/update/by_id/$id",
      ),

      headers: headers,

      body: jsonEncode({

        "status":status,

        "reason":reason,
      }),
    );

    if(response.statusCode!=200){

      throw Exception(
        response.body,
      );
    }
  }



//================================
// CHECK
//================================

  Future<Map<String,dynamic>>
      checkIdentityByUserId(
    String userId,
  ) async {

    final response =
        await http.get(

      Uri.parse(
        "$baseUrl/carer/identity/check/$userId",
      ),

      headers: headers,
    );

    if(response.statusCode==200){

      return jsonDecode(
        response.body,
      );
    }

    throw Exception(
      response.body,
    );
  }



//================================
// STATUS
//================================

  Future<String> getStatus(
    String userId,
  ) async {

    final response =
        await http.get(

      Uri.parse(
        "$baseUrl/carer/identity/get/by_user_id/$userId",
      ),

      headers: headers,
    );

    if(response.statusCode==200){

      final json =
          jsonDecode(
        response.body,
      );

      return json["status"]
          ?? "pending";
    }

    throw Exception(
      response.body,
    );
  }



//================================
// PROFILE PIC
//================================

  Future<String?> getProfilePicture(
    String userId,
  ) async {

    final response =
        await http.get(

      Uri.parse(
        "$baseUrl/carer/identity/profile_picture/$userId",
      ),

      headers: headers,
    );

    if(response.statusCode==200){

      final json =
          jsonDecode(
        response.body,
      );

      return json["file_url"];
    }

    return null;
  }
}