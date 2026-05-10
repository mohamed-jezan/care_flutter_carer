class OnboardingBackground {
  final String? id;
  final String userId;
  final int? yearsExperience;
  final List<PreviousJob>? previousJobs;
  final List<Reference>? references;
  final List<Qualification>? qualifications;
  final List<String>? specialistTraining;
  final List<String>? mandatoryTraining;
  final String? dbsCertificateNumber;
  final String? dbsIssueDate;
  final String? dbsFileUrl;
  final String? dbsFileKey;
  final String? cvFileUrl;
  final String? cvFileKey;
  final bool? wwcc;
  final String? status;
  final DateTime? created;
  final String? createdBy;
  final DateTime? updated;
  final String? updatedBy;

  OnboardingBackground({
    this.id,
    required this.userId,
    this.yearsExperience,
    this.previousJobs,
    this.references,
    this.qualifications,
    this.specialistTraining,
    this.mandatoryTraining,
    this.dbsCertificateNumber,
    this.dbsIssueDate,
    this.dbsFileUrl,
    this.dbsFileKey,
    this.cvFileUrl,
    this.cvFileKey,
    this.wwcc,
    this.status,
    this.created,
    this.createdBy,
    this.updated,
    this.updatedBy,
  });

  factory OnboardingBackground.fromJson(Map<String, dynamic> json) {
    return OnboardingBackground(
      id: json['id'] as String?,
      userId: json['user_id'] as String? ?? '',
      yearsExperience: json['years_experience'] != null
          ? int.tryParse(json['years_experience'].toString())
          : null,
      // API returns key 'previousJobs'
      previousJobs: json['previousJobs'] != null
          ? (json['previousJobs'] as List<dynamic>)
              .map((job) => PreviousJob.fromJson(job as Map<String, dynamic>))
              .toList()
          : null,
      // API returns key 'carerReferences'
      references: json['carerReferences'] != null
          ? (json['carerReferences'] as List<dynamic>)
              .map((ref) => Reference.fromJson(ref as Map<String, dynamic>))
              .toList()
          : null,
      // API returns key 'qualifications' (not 'qualificationsData')
      qualifications: json['qualifications'] != null
          ? (json['qualifications'] as List<dynamic>)
              .map((qual) => Qualification.fromJson(qual as Map<String, dynamic>))
              .toList()
          : null,
      // API returns [{training_name: 'x'}] so we extract the string
      specialistTraining: json['specialistTraining'] != null
          ? (json['specialistTraining'] as List<dynamic>)
              .map((e) => (e is Map ? e['training_name'] : e) as String)
              .toList()
          : null,
      mandatoryTraining: json['mandatoryTraining'] != null
          ? (json['mandatoryTraining'] as List<dynamic>)
              .map((e) => (e is Map ? e['training_name'] : e) as String)
              .toList()
          : null,
      dbsCertificateNumber: json['dbs_certificate_number'] as String?,
      dbsIssueDate: json['dbs_issue_date'] as String?,
      dbsFileUrl: json['dbs_file_url'] as String?,
      dbsFileKey: json['dbs_file_key'] as String?,
      cvFileUrl: json['cv_file_url'] as String?,
      cvFileKey: json['cv_file_key'] as String?,
      wwcc: json['wwcc'] as bool?,
      status: json['status'] as String?,
      created: json['created'] != null
          ? DateTime.tryParse(json['created'].toString())
          : null,
      createdBy: json['created_by'] as String?,
      updated: json['updated'] != null
          ? DateTime.tryParse(json['updated'].toString())
          : null,
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'years_experience': yearsExperience?.toString(),
      'previousJobs': previousJobs?.map((job) => job.toJson()).toList(),
      'carerReferences': references?.map((ref) => ref.toJson()).toList(),
      'qualifications': qualifications?.map((qual) => qual.toJson()).toList(),
      'specialistTraining': specialistTraining,
      'mandatoryTraining': mandatoryTraining,
      'dbs_certificate_number': dbsCertificateNumber,
      'dbs_issue_date': dbsIssueDate,
      'dbs_file_url': dbsFileUrl,
      'dbs_file_key': dbsFileKey,
      'cv_file_url': cvFileUrl,
      'cv_file_key': cvFileKey,
      'wwcc': wwcc,
      'status': status,
      'created': created?.toIso8601String(),
      'created_by': createdBy,
      'updated': updated?.toIso8601String(),
      'updated_by': updatedBy,
    };
  }
}

class PreviousJob {
  final String? employer;
  final String? title;
  final String? startDate;
  final String? endDate;
  final String? referenceName;
  final String? referencePhone;
  final String? referenceEmail;

  PreviousJob({
    this.employer,
    this.title,
    this.startDate,
    this.endDate,
    this.referenceName,
    this.referencePhone,
    this.referenceEmail,
  });

  factory PreviousJob.fromJson(Map<String, dynamic> json) {
    return PreviousJob(
      employer: json['employer'] as String?,
      title: json['title'] as String?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      referenceName: json['reference_name'] as String?,
      referencePhone: json['reference_phone'] as String?,
      referenceEmail: json['reference_email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employer': employer,
      'title': title,
      'start_date': startDate,
      'end_date': endDate,
      'reference_name': referenceName,
      'reference_phone': referencePhone,
      'reference_email': referenceEmail,
    };
  }
}

class Reference {
  final String? name;
  final String? phone;
  final String? email;

  Reference({this.name, this.phone, this.email});

  factory Reference.fromJson(Map<String, dynamic> json) {
    return Reference(
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
    };
  }
}

class Qualification {
  final String? title;
  final String? issuedBy;
  final String? issueDate;
  final String? fileUrl;
  final String? fileKey;

  Qualification({
    this.title,
    this.issuedBy,
    this.issueDate,
    this.fileUrl,
    this.fileKey,
  });

  factory Qualification.fromJson(Map<String, dynamic> json) {
    return Qualification(
      title: json['title'] as String?,
      issuedBy: json['issued_by'] as String?,
      issueDate: json['issue_date'] as String?,
      fileUrl: json['file_url'] as String?,
      fileKey: json['file_key'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'issued_by': issuedBy,
      'issue_date': issueDate,
      'file_url': fileUrl,
      'file_key': fileKey,
    };
  }
}