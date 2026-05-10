class OnboardingInfo {
  final String id;
  final String userId;
  final String? dob;
  final String? gender;
  final String? nationalityId;
  final String? street;
  final String? city;
  final String? postCode;
  final String? country;
  final String? emerContactName;
  final String? emerRelationship;
  final String? emerPhone;
  final bool? ownCar;
  final int? maxMinutesPerDay;
  final int? maxVisitsPerDay;
  final String createdBy;
  final String created;
  final String? updated;
  final String? updatedBy;
  final String? email;

  OnboardingInfo({
    required this.id,
    required this.userId,
    this.dob,
    this.gender,
    this.nationalityId,
    this.street,
    this.city,
    this.postCode,
    this.country,
    this.emerContactName,
    this.emerRelationship,
    this.emerPhone,
    this.ownCar,
    this.maxMinutesPerDay,
    this.maxVisitsPerDay,
    required this.createdBy,
    required this.created,
    this.updated,
    this.updatedBy,
    this.email
  });

  factory OnboardingInfo.fromJson(Map<String, dynamic> json) {
    return OnboardingInfo(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      dob: json['dob'] as String?,
      gender: json['gender'] as String?,
      nationalityId: json['nationality_id']?.toString(),
      street: json['street'] as String?,
      city: json['city'] as String?,
      postCode: json['post_code'] as String?,
      country: json['country'] as String?,
      emerContactName: json['emer_contact_name'] as String?,
      emerRelationship: json['emer_relationship'] as String?,
      emerPhone: json['emer_phone'] as String?,
      ownCar: json['own_car'],
      maxMinutesPerDay: json['max_minutes_per_day'] as int,
      maxVisitsPerDay: json['max_visits_per_day'] as int,
      createdBy: json['created_by'] as String,
      created: json['created'] as String,
      updated: json['updated'] as String?,
      updatedBy: json['updated_by'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'dob': dob,
      'gender': gender,
      'nationality_id': nationalityId,
      'street': street,
      'city': city,
      'post_code': postCode,
      'country': country,
      'emer_contact_name': emerContactName,
      'emer_relationship': emerRelationship,
      'emer_phone': emerPhone,
      'own_car' : ownCar,
      'max_minutes_per_day': maxMinutesPerDay,
      'max_visits_per_day' : maxVisitsPerDay,
      'created_by': createdBy,
      'created': created,
      'updated': updated,
      'updated_by': updatedBy,
      'email' : email,
    };
  }
}