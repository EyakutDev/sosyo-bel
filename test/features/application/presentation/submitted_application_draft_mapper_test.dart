import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/features/application/domain/submitted_application_details.dart';
import 'package:sosyo_bel/features/application/presentation/mappers/submitted_application_draft_mapper.dart';

import '../../../support/application_reference_test_catalog.dart';

void main() {
  test('sunucu detayini mevcut basvuru taslagina donusturur', () {
    final draft = SubmittedApplicationDraftMapper.toDraft(
      _details,
      applicationReferenceTestCatalog,
    );

    expect(draft.applicationForm?.identityNumber, '10000000146');
    expect(draft.applicationForm?.birthDate, '01/01/1982');
    expect(draft.applicationForm?.phoneNumber, '5345512873');
    expect(draft.applicationForm?.helpTypeCode, 'GIDA');
    expect(draft.applicationForm?.disabilityStatusCode, 'ORTOPEDIK');
    expect(draft.kpsProfile?.fullAddress, 'ÖRNEK MAH. TEST SK.');
    expect(draft.citizenProfile.fullName, 'TEST ÖRNEK');
    expect(draft.familyInformation.members.single.relationship, 'Teyze');
    expect(
      draft.familyInformation.members.single.details?.employmentStatusCode,
      'CALISIYOR',
    );
    expect(draft.householdStatus?.answers['MULKIYET_DURUMU'], 'KIRACI');
    expect(draft.householdStatus?.photos, hasLength(1));
    expect(draft.householdStatus?.photos.single.remotePhotoId, 91);
    expect(draft.householdStatus?.replaceRemotePhotosOnSave, isTrue);
    expect(draft.completionNote, 'Mevcut saha notu');
  });

  test('eksik zorunlu aile kodunu duzenleme oncesinde reddeder', () {
    final invalid = SubmittedApplicationDetails(
      applicationId: _details.applicationId,
      applicationNumber: _details.applicationNumber,
      statusCode: _details.statusCode,
      isOwnedByCurrentUser: true,
      isEditable: true,
      applicationDate: _details.applicationDate,
      identityNumber: _details.identityNumber,
      firstName: _details.firstName,
      lastName: _details.lastName,
      birthDate: _details.birthDate,
      phoneNumber: _details.phoneNumber,
      helpTypeCode: _details.helpTypeCode,
      hasDisability: _details.hasDisability,
      disabilityTypeCode: _details.disabilityTypeCode,
      familyMembers: const [
        SubmittedApplicationFamilyMember(
          fullName: 'Ayşe Yılmaz',
          age: 42,
          relationshipCode: null,
          hasDisability: false,
          employmentStatusCode: 'CALISIYOR',
          educationStatusCode: 'LISE',
          vitalStatusCode: 'SAG',
        ),
      ],
      householdAnswers: const [],
      photos: const [],
    );

    expect(
      () => SubmittedApplicationDraftMapper.toDraft(
        invalid,
        applicationReferenceTestCatalog,
      ),
      throwsFormatException,
    );
  });
}

final _details = SubmittedApplicationDetails(
  applicationId: 3751,
  applicationPublicId: '22222222-2222-2222-2222-222222222222',
  applicationNumber: '#3751',
  statusCode: 'KURUL_BEKLIYOR',
  isOwnedByCurrentUser: true,
  isEditable: true,
  applicationDate: DateTime.utc(2026, 9, 7, 10, 30),
  identityNumber: '10000000146',
  firstName: 'TEST',
  lastName: 'ÖRNEK',
  birthDate: DateTime(1982, 1, 1),
  phoneNumber: '5345512873',
  helpTypeCode: 'GIDA',
  hasDisability: true,
  disabilityTypeCode: 'ORTOPEDIK',
  description: 'Mevcut açıklama',
  fieldInspectionNote: 'Mevcut saha notu',
  address: 'ÖRNEK MAH. TEST SK.',
  gender: 'Kadın',
  birthPlace: 'MERKEZ',
  maritalStatus: 'Evli',
  familyMembers: const [
    SubmittedApplicationFamilyMember(
      fullName: 'Ayşe Yılmaz',
      age: 42,
      relationshipCode: 'DIGER',
      otherRelationshipDescription: 'Teyze',
      hasDisability: false,
      employmentStatusCode: 'CALISIYOR',
      educationStatusCode: 'LISE',
      vitalStatusCode: 'SAG',
    ),
  ],
  householdAnswers: const [
    SubmittedApplicationHouseholdAnswer(
      questionCode: 'MULKIYET_DURUMU',
      optionCode: 'KIRACI',
    ),
  ],
  photos: [
    SubmittedApplicationPhoto(
      photoId: 91,
      urlPath:
          '/uploads/hanefotograflari/22222222222222222222222222222222/salon.jpg',
      uploadedAt: DateTime.utc(2026, 9, 7, 10, 31),
    ),
  ],
);
