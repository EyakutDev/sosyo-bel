import 'package:sosyo_bel/features/activity/presentation/models/citizen_profile_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/application/domain/kps_profile.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

typedef LocalPhotoPathEncoder = String Function(String absolutePath);
typedef LocalPhotoPathDecoder = String Function(String storedPath);

/// Ekran taslağını sürümlü yerel manifestte saklanabilen JSON verisine dönüştürür.
/// API alan adları özellikle kullanılmaz; yerel kayıt ile sunucu sözleşmesi birbirine
/// bağımlı hale gelmez.
abstract final class ApplicationDraftLocalCodec {
  static Map<String, dynamic> toJson(
    ApplicationDraft draft, {
    required LocalPhotoPathEncoder encodeFilePhotoPath,
  }) => {
    'applicationForm': _formToJson(draft.applicationForm),
    'kpsProfile': _kpsToJson(draft.kpsProfile),
    'citizenProfile': _citizenToJson(draft.citizenProfile),
    'familyInformation': _familyToJson(draft.familyInformation),
    'householdStatus': _householdToJson(
      draft.householdStatus,
      encodeFilePhotoPath,
    ),
    'completionNote': draft.completionNote,
  };

  static ApplicationDraft fromJson(
    Map<String, dynamic> json, {
    required LocalPhotoPathDecoder decodeFilePhotoPath,
  }) => ApplicationDraft(
    applicationForm: _formFromJson(_optionalMap(json['applicationForm'])),
    kpsProfile: _kpsFromJson(_optionalMap(json['kpsProfile'])),
    citizenProfile: _citizenFromJson(_requiredMap(json, 'citizenProfile')),
    familyInformation: _familyFromJson(_requiredMap(json, 'familyInformation')),
    householdStatus: _householdFromJson(
      _optionalMap(json['householdStatus']),
      decodeFilePhotoPath,
    ),
    completionNote: _requiredString(json, 'completionNote'),
  );

  static Map<String, dynamic>? _formToJson(NewApplicationFormData? value) =>
      value == null
      ? null
      : {
          'identityNumber': value.identityNumber,
          'birthDate': value.birthDate,
          'disabilityStatusCode': value.disabilityStatusCode,
          'disabilityStatus': value.disabilityStatus,
          'phoneNumber': value.phoneNumber,
          'helpTypeCode': value.helpTypeCode,
          'helpType': value.helpType,
          'description': value.description,
        };

  static NewApplicationFormData? _formFromJson(Map<String, dynamic>? json) =>
      json == null
      ? null
      : NewApplicationFormData(
          identityNumber: _requiredString(json, 'identityNumber'),
          birthDate: _requiredString(json, 'birthDate'),
          disabilityStatusCode: _requiredString(json, 'disabilityStatusCode'),
          disabilityStatus: _requiredString(json, 'disabilityStatus'),
          phoneNumber: _requiredString(json, 'phoneNumber'),
          helpTypeCode: _requiredString(json, 'helpTypeCode'),
          helpType: _requiredString(json, 'helpType'),
          description: _requiredString(json, 'description'),
        );

  static Map<String, dynamic>? _kpsToJson(KpsProfile? value) => value == null
      ? null
      : {
          'identityNumber': value.identityNumber,
          'firstName': value.firstName,
          'lastName': value.lastName,
          'fatherName': value.fatherName,
          'motherName': value.motherName,
          'birthDate': value.birthDate,
          'birthPlace': value.birthPlace,
          'gender': value.gender,
          'maritalStatus': value.maritalStatus,
          'status': value.status,
          'fullAddress': value.fullAddress,
        };

  static KpsProfile? _kpsFromJson(Map<String, dynamic>? json) => json == null
      ? null
      : KpsProfile(
          identityNumber: _requiredString(json, 'identityNumber'),
          firstName: _requiredString(json, 'firstName'),
          lastName: _requiredString(json, 'lastName'),
          fatherName: _optionalString(json, 'fatherName'),
          motherName: _optionalString(json, 'motherName'),
          birthDate: _requiredString(json, 'birthDate'),
          birthPlace: _optionalString(json, 'birthPlace'),
          gender: _optionalString(json, 'gender'),
          maritalStatus: _optionalString(json, 'maritalStatus'),
          status: _optionalString(json, 'status'),
          fullAddress: _requiredString(json, 'fullAddress'),
        );

  static Map<String, dynamic> _citizenToJson(CitizenProfileViewData value) => {
    'applicationNumber': value.applicationNumber,
    'fullName': value.fullName,
    'address': value.address,
    'phoneNumber': value.phoneNumber,
    'identityNumber': value.identityNumber,
    'birthDate': value.birthDate,
    'maritalStatus': value.maritalStatus,
    'childrenCount': value.childrenCount,
    'disabilityStatus': value.disabilityStatus,
    'employmentStatus': value.employmentStatus,
    'educationStatus': value.educationStatus,
  };

  static CitizenProfileViewData _citizenFromJson(Map<String, dynamic> json) =>
      CitizenProfileViewData(
        applicationNumber: _requiredString(json, 'applicationNumber'),
        fullName: _requiredString(json, 'fullName'),
        address: _requiredString(json, 'address'),
        phoneNumber: _requiredString(json, 'phoneNumber'),
        identityNumber: _requiredString(json, 'identityNumber'),
        birthDate: _requiredString(json, 'birthDate'),
        maritalStatus: _requiredString(json, 'maritalStatus'),
        childrenCount: _requiredString(json, 'childrenCount'),
        disabilityStatus: _requiredString(json, 'disabilityStatus'),
        employmentStatus: _requiredString(json, 'employmentStatus'),
        educationStatus: _requiredString(json, 'educationStatus'),
      );

  static Map<String, dynamic> _familyToJson(FamilyInformationViewData value) =>
      {
        'members': value.members
            .map(
              (member) => {
                'fullName': member.fullName,
                'relationshipCode': member.relationshipCode,
                'relationship': member.relationship,
                'age': member.age,
                'details': _familyDetailsToJson(member.details),
              },
            )
            .toList(growable: false),
      };

  static FamilyInformationViewData _familyFromJson(Map<String, dynamic> json) =>
      FamilyInformationViewData(
        members: List.unmodifiable(
          _requiredList(json, 'members').map((value) {
            final member = _mapValue(value, 'familyInformation.members');
            return FamilyMemberViewData(
              fullName: _requiredString(member, 'fullName'),
              relationshipCode: _requiredString(member, 'relationshipCode'),
              relationship: _requiredString(member, 'relationship'),
              age: _requiredString(member, 'age'),
              details: _familyDetailsFromJson(_optionalMap(member['details'])),
            );
          }),
        ),
      );

  static Map<String, dynamic>? _familyDetailsToJson(
    FamilyMemberDetailsViewData? value,
  ) => value == null
      ? null
      : {
          'disabilityStatusCode': value.disabilityStatusCode,
          'disabilityStatus': value.disabilityStatus,
          'employmentStatusCode': value.employmentStatusCode,
          'employmentStatus': value.employmentStatus,
          'educationStatusCode': value.educationStatusCode,
          'educationStatus': value.educationStatus,
          'vitalStatusCode': value.vitalStatusCode,
          'vitalStatus': value.vitalStatus,
        };

  static FamilyMemberDetailsViewData? _familyDetailsFromJson(
    Map<String, dynamic>? json,
  ) => json == null
      ? null
      : FamilyMemberDetailsViewData(
          disabilityStatusCode: _requiredString(json, 'disabilityStatusCode'),
          disabilityStatus: _requiredString(json, 'disabilityStatus'),
          employmentStatusCode: _requiredString(json, 'employmentStatusCode'),
          employmentStatus: _requiredString(json, 'employmentStatus'),
          educationStatusCode: _requiredString(json, 'educationStatusCode'),
          educationStatus: _requiredString(json, 'educationStatus'),
          vitalStatusCode: _requiredString(json, 'vitalStatusCode'),
          vitalStatus: _requiredString(json, 'vitalStatus'),
        );

  static Map<String, dynamic>? _householdToJson(
    HouseholdStatusDraft? value,
    LocalPhotoPathEncoder encodeFilePhotoPath,
  ) => value == null
      ? null
      : {
          'answers': value.answers,
          'photos': value.photos
              .map(
                (photo) => {
                  'kind': photo.kind.name,
                  'path': photo.kind == HouseholdPhotoKind.file
                      ? encodeFilePhotoPath(photo.path)
                      : photo.path,
                },
              )
              .toList(growable: false),
          'saveToBeneficiaryDirectory': value.saveToBeneficiaryDirectory,
          'replaceRemotePhotosOnSave': value.replaceRemotePhotosOnSave,
        };

  static HouseholdStatusDraft? _householdFromJson(
    Map<String, dynamic>? json,
    LocalPhotoPathDecoder decodeFilePhotoPath,
  ) {
    if (json == null) return null;

    final rawAnswers = _requiredMap(json, 'answers');
    final answers = <String, String>{};
    for (final entry in rawAnswers.entries) {
      if (entry.value is! String) {
        throw const FormatException('Yerel hane cevabı geçersiz.');
      }
      answers[entry.key] = entry.value as String;
    }

    final photos = _requiredList(json, 'photos')
        .map((value) {
          final photo = _mapValue(value, 'householdStatus.photos');
          final kind = _requiredString(photo, 'kind');
          final path = _requiredString(photo, 'path');
          return switch (kind) {
            'asset' => HouseholdPhotoViewData.asset(path),
            'file' => HouseholdPhotoViewData.file(decodeFilePhotoPath(path)),
            _ => throw const FormatException('Yerel fotoğraf türü geçersiz.'),
          };
        })
        .toList(growable: false);
    if (photos.length > HouseholdPhotoPolicy.maxPhotoCount) {
      throw const FormatException('Yerel taslak fotoğraf sınırını aşıyor.');
    }

    return HouseholdStatusDraft(
      answers: Map.unmodifiable(answers),
      photos: List.unmodifiable(photos),
      saveToBeneficiaryDirectory: _requiredBool(
        json,
        'saveToBeneficiaryDirectory',
      ),
      replaceRemotePhotosOnSave: _requiredBool(
        json,
        'replaceRemotePhotosOnSave',
      ),
    );
  }

  static Map<String, dynamic> _requiredMap(
    Map<String, dynamic> json,
    String key,
  ) => _mapValue(json[key], key);

  static Map<String, dynamic>? _optionalMap(Object? value) =>
      value == null ? null : _mapValue(value, 'optional');

  static Map<String, dynamic> _mapValue(Object? value, String fieldName) {
    if (value is! Map) {
      throw FormatException('$fieldName alanı geçersiz.');
    }
    return value.map((key, dynamic item) => MapEntry(key.toString(), item));
  }

  static List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) throw FormatException('$key alanı geçersiz.');
    return value;
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) throw FormatException('$key alanı geçersiz.');
    return value;
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('$key alanı geçersiz.');
    return value;
  }

  static bool _requiredBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) throw FormatException('$key alanı geçersiz.');
    return value;
  }
}
