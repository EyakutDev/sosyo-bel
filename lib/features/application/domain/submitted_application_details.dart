/// Veritabanına gönderilmiş bir başvurunun detay ekranı için gereken sunucu
/// görünümüdür. Kullanıcıya gösterilecek etiketler referans kataloğundan çözülür.
final class SubmittedApplicationDetails {
  const SubmittedApplicationDetails({
    required this.applicationId,
    required this.applicationNumber,
    required this.statusCode,
    required this.isOwnedByCurrentUser,
    required this.isEditable,
    required this.applicationDate,
    required this.identityNumber,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.helpTypeCode,
    required this.hasDisability,
    required this.familyMembers,
    required this.householdAnswers,
    required this.photos,
    this.applicationPublicId,
    this.birthDate,
    this.disabilityTypeCode,
    this.disabilityRate,
    this.description,
    this.fieldInspectionNote,
    this.address,
    this.gender,
    this.birthPlace,
    this.maritalStatus,
    this.cancellationDescription,
    this.cancellationDate,
  });

  final int applicationId;
  final String? applicationPublicId;
  final String applicationNumber;
  final String statusCode;
  final bool isOwnedByCurrentUser;
  final bool isEditable;
  final DateTime applicationDate;
  final String identityNumber;
  final String firstName;
  final String lastName;
  final DateTime? birthDate;
  final String phoneNumber;
  final String helpTypeCode;
  final bool hasDisability;
  final String? disabilityTypeCode;
  final int? disabilityRate;
  final String? description;
  final String? fieldInspectionNote;
  final String? address;
  final String? gender;
  final String? birthPlace;
  final String? maritalStatus;
  final String? cancellationDescription;
  final DateTime? cancellationDate;
  final List<SubmittedApplicationFamilyMember> familyMembers;
  final List<SubmittedApplicationHouseholdAnswer> householdAnswers;
  final List<SubmittedApplicationPhoto> photos;

  factory SubmittedApplicationDetails.fromJson(Map<String, dynamic> json) {
    return SubmittedApplicationDetails(
      applicationId: _requiredPositiveInt(json, 'applicationId'),
      applicationPublicId: _optionalString(json, 'applicationPublicId'),
      applicationNumber: _requiredString(json, 'applicationNumber'),
      statusCode: _requiredString(json, 'statusCode').toUpperCase(),
      isOwnedByCurrentUser: _requiredBool(json, 'isOwnedByCurrentUser'),
      isEditable: _requiredBool(json, 'isEditable'),
      applicationDate: _requiredDateTime(json, 'applicationDate'),
      identityNumber: _requiredString(json, 'identityNumber'),
      firstName: _requiredString(json, 'firstName'),
      lastName: _requiredString(json, 'lastName'),
      birthDate: _optionalDateTime(json, 'birthDate'),
      phoneNumber: _requiredString(json, 'phoneNumber'),
      helpTypeCode: _requiredString(json, 'helpTypeCode'),
      hasDisability: _requiredBool(json, 'hasDisability'),
      disabilityTypeCode: _optionalString(json, 'disabilityTypeCode'),
      disabilityRate: _optionalNonNegativeInt(json, 'disabilityRate'),
      description: _optionalString(json, 'description'),
      fieldInspectionNote: _optionalString(json, 'fieldInspectionNote'),
      address: _optionalString(json, 'address'),
      gender: _optionalString(json, 'gender'),
      birthPlace: _optionalString(json, 'birthPlace'),
      maritalStatus: _optionalString(json, 'maritalStatus'),
      cancellationDescription: _optionalString(json, 'cancellationDescription'),
      cancellationDate: _optionalDateTime(json, 'cancellationDate'),
      familyMembers: List.unmodifiable(
        _requiredList(json, 'familyMembers').map(
          (value) => SubmittedApplicationFamilyMember.fromJson(
            _requiredMap(value, 'familyMembers[]'),
          ),
        ),
      ),
      householdAnswers: List.unmodifiable(
        _requiredList(json, 'householdAnswers').map(
          (value) => SubmittedApplicationHouseholdAnswer.fromJson(
            _requiredMap(value, 'householdAnswers[]'),
          ),
        ),
      ),
      photos: List.unmodifiable(
        _requiredList(json, 'photos').map(
          (value) => SubmittedApplicationPhoto.fromJson(
            _requiredMap(value, 'photos[]'),
          ),
        ),
      ),
    );
  }
}

final class SubmittedApplicationFamilyMember {
  const SubmittedApplicationFamilyMember({
    required this.fullName,
    required this.age,
    required this.hasDisability,
    this.relationshipCode,
    this.otherRelationshipDescription,
    this.disabilityTypeCode,
    this.disabilityDescription,
    this.employmentStatusCode,
    this.educationStatusCode,
    this.vitalStatusCode,
  });

  final String fullName;
  final int age;
  final String? relationshipCode;
  final String? otherRelationshipDescription;
  final bool hasDisability;
  final String? disabilityTypeCode;
  final String? disabilityDescription;
  final String? employmentStatusCode;
  final String? educationStatusCode;
  final String? vitalStatusCode;

  factory SubmittedApplicationFamilyMember.fromJson(Map<String, dynamic> json) {
    return SubmittedApplicationFamilyMember(
      fullName: _requiredString(json, 'fullName'),
      age: _requiredNonNegativeInt(json, 'age'),
      relationshipCode: _optionalString(json, 'relationshipCode'),
      otherRelationshipDescription: _optionalString(
        json,
        'otherRelationshipDescription',
      ),
      hasDisability: _requiredBool(json, 'hasDisability'),
      disabilityTypeCode: _optionalString(json, 'disabilityTypeCode'),
      disabilityDescription: _optionalString(json, 'disabilityDescription'),
      employmentStatusCode: _optionalString(json, 'employmentStatusCode'),
      educationStatusCode: _optionalString(json, 'educationStatusCode'),
      vitalStatusCode: _optionalString(json, 'vitalStatusCode'),
    );
  }
}

final class SubmittedApplicationHouseholdAnswer {
  const SubmittedApplicationHouseholdAnswer({
    required this.questionCode,
    required this.optionCode,
  });

  final String questionCode;
  final String optionCode;

  factory SubmittedApplicationHouseholdAnswer.fromJson(
    Map<String, dynamic> json,
  ) {
    return SubmittedApplicationHouseholdAnswer(
      questionCode: _requiredString(json, 'questionCode'),
      optionCode: _requiredString(json, 'optionCode'),
    );
  }
}

final class SubmittedApplicationPhoto {
  const SubmittedApplicationPhoto({
    required this.photoId,
    required this.urlPath,
    required this.uploadedAt,
    this.description,
  });

  final int photoId;
  final String urlPath;
  final String? description;
  final DateTime uploadedAt;

  factory SubmittedApplicationPhoto.fromJson(Map<String, dynamic> json) {
    return SubmittedApplicationPhoto(
      photoId: _requiredPositiveInt(json, 'photoId'),
      urlPath: _requiredString(json, 'urlPath'),
      description: _optionalString(json, 'description'),
      uploadedAt: _requiredDateTime(json, 'uploadedAt'),
    );
  }
}

final class SubmittedApplicationUpdateResult {
  const SubmittedApplicationUpdateResult({
    required this.applicationId,
    required this.applicationNumber,
    required this.statusCode,
    required this.isEditable,
    this.applicationPublicId,
  });

  final int applicationId;
  final String? applicationPublicId;
  final String applicationNumber;
  final String statusCode;
  final bool isEditable;

  factory SubmittedApplicationUpdateResult.fromJson(Map<String, dynamic> json) {
    return SubmittedApplicationUpdateResult(
      applicationId: _requiredPositiveInt(json, 'applicationId'),
      applicationPublicId: _optionalString(json, 'applicationPublicId'),
      applicationNumber: _requiredString(json, 'applicationNumber'),
      statusCode: _requiredString(json, 'statusCode').toUpperCase(),
      isEditable: _requiredBool(json, 'isEditable'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key alanı eksik veya geçersiz.');
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key alanı geçersiz.');
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _requiredPositiveInt(Map<String, dynamic> json, String key) {
  final value = _requiredInteger(json, key);
  if (value <= 0) throw FormatException('$key alanı geçersiz.');
  return value;
}

int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
  final value = _requiredInteger(json, key);
  if (value < 0) throw FormatException('$key alanı geçersiz.');
  return value;
}

int? _optionalNonNegativeInt(Map<String, dynamic> json, String key) {
  if (json[key] == null) return null;
  return _requiredNonNegativeInt(json, key);
}

int _requiredInteger(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || value.toInt() != value) {
    throw FormatException('$key alanı geçersiz.');
  }
  return value.toInt();
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key alanı geçersiz.');
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse(json[key]?.toString() ?? '');
  if (value == null) throw FormatException('$key alanı geçersiz.');
  return value;
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  if (json[key] == null) return null;
  return _requiredDateTime(json, key);
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('$key alanı geçersiz.');
  return value;
}

Map<String, dynamic> _requiredMap(Object? value, String field) {
  if (value is! Map) throw FormatException('$field alanı geçersiz.');
  return Map<String, dynamic>.from(value);
}
