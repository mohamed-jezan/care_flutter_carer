// lib/model/carer_availability.dart
//
// Maps to backend table: carer_availability
// Schema:
//   id UUID, user_id UUID,
//   availability_type ENUM('recurring','specific_date'),
//   day_of_week INTEGER 0-6 (nullable, only for recurring),
//   available_date DATEONLY (nullable, only for specific_date),
//   start_time TIME, end_time TIME,
//   is_available BOOLEAN,
//   status ENUM('pending','approved','rejected','active','inactive'),
//   created, created_by, updated, updated_by

class CarerAvailability {
  final String id;
  final String userId;

  /// 'recurring' or 'specific_date'
  final String availabilityType;

  /// 0 = Sunday … 6 = Saturday (only set when availabilityType == 'recurring')
  final int? dayOfWeek;

  /// ISO date string 'yyyy-MM-dd' (only set when availabilityType == 'specific_date')
  final String? availableDate;

  /// 'HH:mm' or 'HH:mm:ss'  — backend stores TIME
  final String startTime;
  final String endTime;

  final bool isAvailable;
  final String status;
  final String? createdBy;
  final DateTime? created;
  final DateTime? updated;
  final String? updatedBy;

  const CarerAvailability({
    required this.id,
    required this.userId,
    required this.availabilityType,
    this.dayOfWeek,
    this.availableDate,
    required this.startTime,
    required this.endTime,
    this.isAvailable = true,
    this.status = 'pending',
    this.createdBy,
    this.created,
    this.updated,
    this.updatedBy,
  });

  factory CarerAvailability.fromJson(Map<String, dynamic> json) {
    return CarerAvailability(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      availabilityType: json['availability_type']?.toString() ?? 'recurring',
      dayOfWeek: json['day_of_week'] != null
          ? int.tryParse(json['day_of_week'].toString())
          : null,
      availableDate: json['available_date']?.toString(),
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      // is_available can come as bool or tinyint (0/1) from MySQL
      isAvailable: json['is_available'] == true || json['is_available'] == 1,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'availability_type': availabilityType,
        'day_of_week': dayOfWeek,
        'available_date': availableDate,
        'start_time': startTime,
        'end_time': endTime,
        'is_available': isAvailable,
        'status': status,
        'created_by': createdBy,
        'created': created?.toIso8601String(),
        'updated': updated?.toIso8601String(),
        'updated_by': updatedBy,
      };

  /// Payload sent inside the 'availabilities' array for bulk-create.
  /// Backend validateAvailabilityItem reads these exact keys.
  Map<String, dynamic> toBulkCreateItem() {
    final Map<String, dynamic> item = {
      'availability_type': availabilityType,
      'start_time': startTime,
      'end_time': endTime,
      'is_available': isAvailable,
      'status': status,
    };
    if (availabilityType == 'recurring') {
      item['day_of_week'] = dayOfWeek;
    } else {
      item['available_date'] = availableDate;
    }
    return item;
  }

  /// Payload for PUT /carer/availability/update/:id
  Map<String, dynamic> toUpdateJson({required String updatedBy}) {
    final Map<String, dynamic> payload = {
      'availability_type': availabilityType,
      'start_time': startTime,
      'end_time': endTime,
      'is_available': isAvailable,
      'status': status,
      'updated_by': updatedBy,
    };
    if (availabilityType == 'recurring') {
      payload['day_of_week'] = dayOfWeek;
    } else {
      payload['available_date'] = availableDate;
    }
    return payload;
  }

  /// Human-readable label for day_of_week (0 = Sunday … 6 = Saturday)
  static const List<String> dayNames = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday',
  ];

  String get dayLabel =>
      (dayOfWeek != null && dayOfWeek! >= 0 && dayOfWeek! <= 6)
          ? dayNames[dayOfWeek!]
          : '';
}