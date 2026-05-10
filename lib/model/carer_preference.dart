class CarerPreference {
  final String id;
  final String userId;
  final String preferredClientGender; // 'Male' | 'Female' | 'Any'
  final String partTimePreference;    // 'part-time' | 'full-time' (backend values)
  final String status;                // 'pending' | 'approved' | 'rejected'
  final String? createdBy;
  final DateTime? created;
  final DateTime? updated;
  final String? updatedBy;

  CarerPreference({
    required this.id,
    required this.userId,
    required this.preferredClientGender,
    required this.partTimePreference,
    this.status = 'pending',
    this.createdBy,
    this.created,
    this.updated,
    this.updatedBy,
  });

  factory CarerPreference.fromJson(Map<String, dynamic> json) {
    return CarerPreference(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      preferredClientGender: json['preferred_client_gender']?.toString() ?? '',
      partTimePreference: json['part_time_preference']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdBy: json['created_by']?.toString(),
      created: json['created'] != null
          ? DateTime.tryParse(json['created'].toString())
          : null,
      updated: json['updated'] != null
          ? DateTime.tryParse(json['updated'].toString())
          : null,
      updatedBy: json['updated_by']?.toString(),
    );
  }

  /// Payload for POST /carer/preferences/create
  Map<String, dynamic> toCreateJson({required String userId, required String createdBy}) {
    return {
      'user_id': userId,
      'preferred_client_gender': preferredClientGender,
      'part_time_preference': partTimePreference,
      'status': 'pending',
      'created_by': createdBy,
    };
  }

  /// Payload for PUT /carer/preferences/update/:user_id
  Map<String, dynamic> toUpdateJson({required String updatedBy}) {
    return {
      'preferred_client_gender': preferredClientGender,
      'part_time_preference': partTimePreference,
      'updated_by': updatedBy,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'preferred_client_gender': preferredClientGender,
      'part_time_preference': partTimePreference,
      'status': status,
      'created_by': createdBy,
      'created': created?.toIso8601String(),
      'updated': updated?.toIso8601String(),
      'updated_by': updatedBy,
    };
  }
}