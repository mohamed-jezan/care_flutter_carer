class CarerSkill {
  final String id;
  final String userId;
  final String skill; // maps to backend column 'skills' (STRING 50) — one row per skill
  final String status;
  final String? createdBy;
  final DateTime? created;
  final DateTime? updated;
  final String? updatedBy;
 
  CarerSkill({
    required this.id,
    required this.userId,
    required this.skill,
    this.status = 'pending',
    this.createdBy,
    this.created,
    this.updated,
    this.updatedBy,
  });
 
  factory CarerSkill.fromJson(Map<String, dynamic> json) {
    return CarerSkill(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      skill: json['skills']?.toString() ?? '', // backend column name is 'skills'
      status: json['status']?.toString() ?? 'pending',
      createdBy: json['created_by']?.toString(),
      created: json['created'] != null ? DateTime.tryParse(json['created'].toString()) : null,
      updated: json['updated'] != null ? DateTime.tryParse(json['updated'].toString()) : null,
      updatedBy: json['updated_by']?.toString(),
    );
  }
 
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'skills': skill, // backend column name is 'skills'
        'status': status,
        'created_by': createdBy,
        'created': created?.toIso8601String(),
        'updated': updated?.toIso8601String(),
        'updated_by': updatedBy,
      };
 
  /// Payload for creating a new skill row (excludes id, timestamps)
  Map<String, dynamic> toCreateJson() => {
        'user_id': userId,
        'skills': skill,
        'status': status,
        'created_by': createdBy,
      };
}