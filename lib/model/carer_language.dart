class CarerLanguage {
  final String id;
  final String userId;
  final int languageId; // INTEGER in backend — FK to languages table
  final bool isPrimary; // is_primary BOOLEAN
  final String status;
  final String? createdBy;
  final DateTime? created;
  final DateTime? updated;
  final String? updatedBy;

  // Populated when backend includes the Sequelize association (languageDetails)
  final String? langEN;

  CarerLanguage({
    required this.id,
    required this.userId,
    required this.languageId,
    this.isPrimary = false,
    this.status = 'pending',
    this.createdBy,
    this.created,
    this.updated,
    this.updatedBy,
    this.langEN,
  });

  factory CarerLanguage.fromJson(Map<String, dynamic> json) {
    return CarerLanguage(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      // language_id is INTEGER — handle both int and string safely
      languageId: json['language_id'] is int
          ? json['language_id'] as int
          : int.tryParse(json['language_id']?.toString() ?? '0') ?? 0,
      // is_primary can come as bool or int (0/1) from Sequelize
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
      status: json['status']?.toString() ?? 'pending',
      createdBy: json['created_by']?.toString(),
      created: json['created'] != null ? DateTime.tryParse(json['created'].toString()) : null,
      updated: json['updated'] != null ? DateTime.tryParse(json['updated'].toString()) : null,
      updatedBy: json['updated_by']?.toString(),
      // Populated if backend includes the association
      langEN: json['languageDetails'] != null
          ? json['languageDetails']['langEN']?.toString()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'language_id': languageId,
        'is_primary': isPrimary,
        'status': status,
        'created_by': createdBy,
        'created': created?.toIso8601String(),
        'updated': updated?.toIso8601String(),
        'updated_by': updatedBy,
      };

  /// Payload for creating a new language row (excludes id, timestamps)
  Map<String, dynamic> toCreateJson() => {
        'user_id': userId,
        'language_id': languageId,
        'is_primary': isPrimary,
        'status': status,
        'created_by': createdBy,
      };
}