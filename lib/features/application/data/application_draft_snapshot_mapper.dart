import 'package:sosyo_bel/features/activity/presentation/models/citizen_profile_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/application/domain/application_lifecycle_entry.dart';
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';
import 'package:sosyo_bel/features/application/domain/application_repository.dart';
import 'package:sosyo_bel/features/application/domain/kps_profile.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

class ApplicationPhotoReference {
  const ApplicationPhotoReference({
    required this.photoId,
    required this.contentType,
    required this.length,
    required this.order,
    this.originalFileName,
  });

  final int photoId;
  final String? originalFileName;
  final String contentType;
  final int length;
  final int order;
}

/// Snapshot API kodlarını mevcut ekran etiketlerine geri çevirir. Ters eşleme
/// yazma mapper'ından ayrı tutulur; sunucudan gelen eksik/bozuk veri sessizce
/// yanlış bir forma dönüşmez.
abstract final class ApplicationDraftSnapshotMapper {
  static List<ApplicationPhotoReference> readPhotoReferences(
    Map<String, dynamic> json,
  ) {
    return _requiredList(json, 'photos')
        .map((value) {
          final photo = _requiredMap(value, 'photos[]');
          return ApplicationPhotoReference(
            photoId: _requiredInt(photo, 'photoId'),
            originalFileName: _optionalString(photo, 'originalFileName'),
            contentType: _requiredString(photo, 'contentType'),
            length: _requiredInt(photo, 'length'),
            order: _requiredInt(photo, 'order'),
          );
        })
        .toList(growable: false)
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  static LoadedApplicationDraft fromJson(
    Map<String, dynamic> json, {
    required List<HouseholdPhotoViewData> photos,
    required ApplicationReferenceCatalog referenceCatalog,
  }) {
    final application = _requiredMap(json['application'], 'application');
    final entry = ApplicationLifecycleEntry.fromJson(application);
    final hasDisability = _requiredBool(application, 'hasDisability');
    final disabilityCode = _optionalString(application, 'disabilityTypeCode');
    final disabilityOption = _requiredReference(
      referenceCatalog.disabilityStatuses,
      hasDisability ? disabilityCode : 'YOK',
      'Engel durumu kodu desteklenmiyor.',
    );
    final birthDate = _formatDate(_requiredString(application, 'birthDate'));
    final firstName = _optionalString(application, 'applicantFirstName');
    final lastName = _optionalString(application, 'applicantLastName');
    final fullName = [
      firstName,
      lastName,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' ');
    final address = _optionalString(application, 'address');
    final kpsProfile = firstName != null && lastName != null && address != null
        ? KpsProfile(
            identityNumber: _requiredString(application, 'identityNumber'),
            firstName: firstName,
            lastName: lastName,
            birthDate: birthDate,
            fullAddress: address,
          )
        : null;

    final familyMembers = _requiredList(json, 'familyMembers')
        .map((value) {
          final member = _requiredMap(value, 'familyMembers[]');
          final relationshipCode = _requiredString(member, 'relationshipCode');
          final relationshipOption = _requiredReference(
            referenceCatalog.relationships,
            relationshipCode,
            'Yakınlık kodu desteklenmiyor.',
          );
          final otherRelationship = _optionalString(
            member,
            'otherRelationshipDescription',
          );
          final employment = _referenceOrNull(
            referenceCatalog.employmentStatuses,
            _optionalString(member, 'employmentStatusCode'),
            'Çalışma durumu kodu desteklenmiyor.',
          );
          final education = _referenceOrNull(
            referenceCatalog.educationStatuses,
            _optionalString(member, 'educationStatusCode'),
            'Eğitim durumu kodu desteklenmiyor.',
          );
          final vital = _referenceOrNull(
            referenceCatalog.vitalStatuses,
            _optionalString(member, 'vitalStatusCode'),
            'Yaşam durumu kodu desteklenmiyor.',
          );
          final memberHasDisability = _requiredBool(member, 'hasDisability');
          final memberDisabilityCode = memberHasDisability
              ? _optionalString(member, 'disabilityTypeCode')
              : 'YOK';
          final memberDisability = _requiredReference(
            referenceCatalog.disabilityStatuses,
            memberDisabilityCode,
            'Aile üyesi engel durumu kodu desteklenmiyor.',
          );
          final details =
              employment == null || education == null || vital == null
              ? null
              : FamilyMemberDetailsViewData(
                  disabilityStatusCode: memberDisability.code,
                  disabilityStatus: memberDisability.label,
                  employmentStatusCode: employment.code,
                  employmentStatus: employment.label,
                  educationStatusCode: education.code,
                  educationStatus: education.label,
                  vitalStatusCode: vital.code,
                  vitalStatus: vital.label,
                );
          return FamilyMemberViewData(
            fullName: _requiredString(member, 'fullName'),
            relationshipCode: relationshipCode,
            relationship: relationshipCode == 'DIGER'
                ? (otherRelationship ?? relationshipOption.label)
                : relationshipOption.label,
            age: _requiredNonNegativeInt(member, 'age').toString(),
            details: details,
          );
        })
        .toList(growable: false);

    final answers = <String, String>{};
    for (final value in _requiredList(json, 'householdAnswers')) {
      final answer = _requiredMap(value, 'householdAnswers[]');
      final questionCode = _requiredString(answer, 'questionCode');
      final optionCode = _requiredString(answer, 'optionCode');
      final question = referenceCatalog.householdQuestions
          .where((value) => value.code == questionCode)
          .firstOrNull;
      final optionExists = question?.options.any(
        (value) => value.code == optionCode,
      );
      if (question == null || optionExists != true) {
        throw const FormatException('Hane cevabı kodu desteklenmiyor.');
      }
      answers[questionCode] = optionCode;
    }

    final helpTypeCode = _requiredString(application, 'helpTypeCode');
    final helpTypeOption = _requiredReference(
      referenceCatalog.helpTypes,
      helpTypeCode,
      'Yardım türü kodu desteklenmiyor.',
    );

    final form = NewApplicationFormData(
      identityNumber: _requiredString(application, 'identityNumber'),
      birthDate: birthDate,
      disabilityStatusCode: disabilityOption.code,
      disabilityStatus: disabilityOption.label,
      phoneNumber: _requiredString(application, 'phoneNumber'),
      helpTypeCode: helpTypeOption.code,
      helpType: helpTypeOption.label,
      description: _optionalString(application, 'description') ?? '',
    );
    final profile = CitizenProfileViewData(
      applicationNumber: entry.applicationNumber,
      fullName: fullName.isEmpty ? 'Bilgi bulunmuyor' : fullName,
      address: address ?? 'Bilgi bulunmuyor',
      phoneNumber: form.phoneNumber,
      identityNumber: form.identityNumber,
      birthDate: form.birthDate,
      maritalStatus: 'Bilgi bulunmuyor',
      childrenCount: 'Bilgi bulunmuyor',
      disabilityStatus: form.disabilityStatus,
      employmentStatus: 'Bilgi bulunmuyor',
      educationStatus: 'Bilgi bulunmuyor',
    );

    return LoadedApplicationDraft(
      entry: entry,
      draft: ApplicationDraft(
        applicationForm: form,
        kpsProfile: kpsProfile,
        citizenProfile: profile,
        familyInformation: FamilyInformationViewData(members: familyMembers),
        householdStatus: HouseholdStatusDraft(
          answers: Map.unmodifiable(answers),
          photos: List.unmodifiable(photos),
          saveToBeneficiaryDirectory:
              json['saveToBeneficiaryDirectory'] == true,
          replaceRemotePhotosOnSave: true,
        ),
        completionNote:
            _optionalString(application, 'fieldInspectionNote') ?? '',
      ),
    );
  }

  static String _formatDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) throw const FormatException('Doğum tarihi geçersiz.');
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  static ApplicationReferenceOption _requiredReference(
    List<ApplicationReferenceOption> options,
    String? code,
    String error,
  ) {
    final option = options.where((value) => value.code == code).firstOrNull;
    if (option == null) throw FormatException(error);
    return option;
  }

  static ApplicationReferenceOption? _referenceOrNull(
    List<ApplicationReferenceOption> options,
    String? code,
    String error,
  ) => code == null ? null : _requiredReference(options, code, error);

  static Map<String, dynamic> _requiredMap(Object? value, String field) {
    if (value is! Map) throw FormatException('$field alanı geçersiz.');
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) throw FormatException('$key alanı geçersiz.');
    return value;
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key alanı eksik veya geçersiz.');
    }
    return value.trim();
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('$key alanı geçersiz.');
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num || value.toInt() != value || value <= 0) {
      throw FormatException('$key alanı eksik veya geçersiz.');
    }
    return value.toInt();
  }

  static int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num || value.toInt() != value || value < 0) {
      throw FormatException('$key alanı eksik veya geçersiz.');
    }
    return value.toInt();
  }

  static bool _requiredBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) throw FormatException('$key alanı geçersiz.');
    return value;
  }
}
