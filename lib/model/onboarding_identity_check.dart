import 'package:equatable/equatable.dart';

class OnboardingIdentityCheck extends Equatable {
  final String id;
  final String userId;
  final String documentType;
  final String? documentNumber;

  final String? fileUrl;
  final String? fileKey;

  final String status;

  final String? reason;
  final String? approveDate;

  final String created;
  final String? createdBy;

  final String? updated;
  final String? updatedBy;

  const OnboardingIdentityCheck({
    required this.id,
    required this.userId,
    required this.documentType,
    this.documentNumber,
    this.fileUrl,
    this.fileKey,
    required this.status,
    this.reason,
    this.approveDate,
    required this.created,
    this.createdBy,
    this.updated,
    this.updatedBy,
  });

  factory OnboardingIdentityCheck.fromJson(
    Map<String, dynamic> json,
  ) {
    return OnboardingIdentityCheck(
      id: json['id'] ?? '',

      userId: json['user_id'] ?? '',

      documentType: json['document_type'] ?? '',

      documentNumber: json['document_number'],

      fileUrl: json['file_url'],

      fileKey: json['file_key'],

      status: json['status'] ?? "pending",

      reason: json['reason'],

      approveDate: json['approve_date'],

      created: json['created'] ?? '',

      createdBy: json['created_by'],

      updated: json['updated'],

      updatedBy: json['updated_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "user_id": userId,
      "document_type": documentType,
      "document_number": documentNumber,
      "file_url": fileUrl,
      "file_key": fileKey,
      "status": status,
      "reason": reason,
      "approve_date": approveDate,
      "created": created,
      "created_by": createdBy,
      "updated": updated,
      "updated_by": updatedBy,
    };
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        documentType,
        documentNumber,
        fileUrl,
        fileKey,
        status,
        reason,
        approveDate,
        created,
        createdBy,
        updated,
        updatedBy,
      ];
}