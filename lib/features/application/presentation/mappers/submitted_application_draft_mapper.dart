import 'package:sosyo_bel/features/activity/presentation/models/citizen_profile_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';
import 'package:sosyo_bel/features/application/domain/kps_profile.dart';
import 'package:sosyo_bel/features/application/domain/submitted_application_details.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

/// Sunucudan okunan düzenlenebilir başvuruyu mevcut mobil ekran taslağına çevirir.
abstract final class SubmittedApplicationDraftMapper {
  static ApplicationDraft toDraft(
    SubmittedApplicationDetails details,
    ApplicationReferenceCatalog catalog,
  ) {
    final birthDate = details.birthDate;
    if (birthDate == null) {
      throw const FormatException(
        'Başvurunun doğum tarihi düzenleme için eksik.',
      );
    }

    final formattedBirthDate = _formatDate(birthDate);
    final disabilityCode = details.hasDisability
        ? _requiredCode(
            catalog.disabilityStatuses,
            details.disabilityTypeCode,
            'engel durumu',
          )
        : _requiredCode(catalog.disabilityStatuses, 'YOK', 'engel durumu');
    final disabilityLabel = _requiredLabel(
      catalog.disabilityStatuses,
      disabilityCode,
      'engel durumu',
    );
    final helpTypeCode = _requiredCode(
      catalog.helpTypes,
      details.helpTypeCode,
      'yardım türü',
    );

    final familyMembers = details.familyMembers
        .map((member) => _familyMember(member, catalog))
        .toList(growable: false);

    return ApplicationDraft(
      applicationForm: NewApplicationFormData(
        identityNumber: details.identityNumber,
        birthDate: formattedBirthDate,
        disabilityStatusCode: disabilityCode,
        disabilityStatus: disabilityLabel,
        phoneNumber: details.phoneNumber,
        helpTypeCode: helpTypeCode,
        helpType: _requiredLabel(
          catalog.helpTypes,
          helpTypeCode,
          'yardım türü',
        ),
        description: details.description ?? '',
      ),
      kpsProfile: KpsProfile(
        identityNumber: details.identityNumber,
        firstName: details.firstName,
        lastName: details.lastName,
        birthDate: formattedBirthDate,
        fullAddress: details.address ?? 'Bilgi bulunmuyor',
        birthPlace: details.birthPlace,
        gender: details.gender,
        maritalStatus: details.maritalStatus,
      ),
      citizenProfile: CitizenProfileViewData(
        applicationNumber: details.applicationNumber,
        fullName: '${details.firstName} ${details.lastName}'.trim(),
        address: details.address ?? 'Bilgi bulunmuyor',
        phoneNumber: details.phoneNumber,
        identityNumber: details.identityNumber,
        birthDate: formattedBirthDate,
        maritalStatus: details.maritalStatus ?? 'Bilgi bulunmuyor',
        childrenCount: familyMembers.length.toString(),
        disabilityStatus: disabilityLabel,
        employmentStatus: 'Bilgi bulunmuyor',
        educationStatus: 'Bilgi bulunmuyor',
      ),
      familyInformation: FamilyInformationViewData(members: familyMembers),
      householdStatus: HouseholdStatusDraft(
        answers: Map.unmodifiable({
          for (final answer in details.householdAnswers)
            answer.questionCode: answer.optionCode,
        }),
        photos: const [],
        saveToBeneficiaryDirectory: false,
      ),
      completionNote: details.fieldInspectionNote ?? '',
    );
  }

  static FamilyMemberViewData _familyMember(
    SubmittedApplicationFamilyMember member,
    ApplicationReferenceCatalog catalog,
  ) {
    final relationshipCode = _requiredCode(
      catalog.relationships,
      member.relationshipCode,
      'yakınlık',
    );
    final disabilityCode = member.hasDisability
        ? _requiredCode(
            catalog.disabilityStatuses,
            member.disabilityTypeCode,
            'aile engel durumu',
          )
        : _requiredCode(catalog.disabilityStatuses, 'YOK', 'aile engel durumu');
    final employmentCode = _requiredCode(
      catalog.employmentStatuses,
      member.employmentStatusCode,
      'çalışma durumu',
    );
    final educationCode = _requiredCode(
      catalog.educationStatuses,
      member.educationStatusCode,
      'eğitim durumu',
    );
    final vitalCode = _requiredCode(
      catalog.vitalStatuses,
      member.vitalStatusCode,
      'yaşam durumu',
    );

    return FamilyMemberViewData(
      fullName: member.fullName,
      relationshipCode: relationshipCode,
      relationship: relationshipCode == 'DIGER'
          ? member.otherRelationshipDescription ?? 'Diğer'
          : _requiredLabel(catalog.relationships, relationshipCode, 'yakınlık'),
      age: member.age.toString(),
      details: FamilyMemberDetailsViewData(
        disabilityStatusCode: disabilityCode,
        disabilityStatus: _requiredLabel(
          catalog.disabilityStatuses,
          disabilityCode,
          'aile engel durumu',
        ),
        employmentStatusCode: employmentCode,
        employmentStatus: _requiredLabel(
          catalog.employmentStatuses,
          employmentCode,
          'çalışma durumu',
        ),
        educationStatusCode: educationCode,
        educationStatus: _requiredLabel(
          catalog.educationStatuses,
          educationCode,
          'eğitim durumu',
        ),
        vitalStatusCode: vitalCode,
        vitalStatus: _requiredLabel(
          catalog.vitalStatuses,
          vitalCode,
          'yaşam durumu',
        ),
      ),
    );
  }

  static String _requiredCode(
    List<ApplicationReferenceOption> options,
    String? code,
    String field,
  ) {
    final normalized = code?.trim();
    if (normalized == null ||
        normalized.isEmpty ||
        !options.any((option) => option.code == normalized)) {
      throw FormatException(
        'Başvurunun $field bilgisi düzenleme için geçersiz.',
      );
    }
    return normalized;
  }

  static String _requiredLabel(
    List<ApplicationReferenceOption> options,
    String code,
    String field,
  ) {
    for (final option in options) {
      if (option.code == code) return option.label;
    }
    throw FormatException('Başvurunun $field bilgisi düzenleme için geçersiz.');
  }

  static String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year.toString().padLeft(4, '0')}';
  }
}
