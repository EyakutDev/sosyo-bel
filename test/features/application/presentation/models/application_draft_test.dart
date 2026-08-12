import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/features/activity/presentation/fixtures/citizen_profile_design_fixture.dart';
import 'package:sosyo_bel/features/activity/presentation/fixtures/family_information_design_fixture.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

void main() {
  test('bir adımı güncellerken diğer başvuru bilgilerini korur', () {
    const initialDraft = ApplicationDraft(
      citizenProfile: CitizenProfileDesignFixture.profile,
      familyInformation: FamilyInformationDesignFixture.family,
    );
    const formData = NewApplicationFormData(
      identityNumber: '12345678901',
      birthDate: '03/11/2002',
      disabilityStatusCode: 'YOK',
      disabilityStatus: 'Yok',
      phoneNumber: '(534)-551-2872',
      helpTypeCode: 'GIDA',
      helpType: 'Gıda Yardımı',
      description: 'Başvuru açıklaması',
    );
    const householdStatus = HouseholdStatusDraft(
      answers: {'MULKIYET_DURUMU': 'EV_SAHIBI'},
      photos: [],
      saveToBeneficiaryDirectory: false,
    );

    final completedDraft = initialDraft
        .copyWith(applicationForm: formData)
        .copyWith(householdStatus: householdStatus)
        .copyWith(completionNote: 'Kurul notu');

    expect(completedDraft.applicationForm, same(formData));
    expect(
      completedDraft.citizenProfile,
      same(CitizenProfileDesignFixture.profile),
    );
    expect(
      completedDraft.familyInformation,
      same(FamilyInformationDesignFixture.family),
    );
    expect(completedDraft.householdStatus, same(householdStatus));
    expect(completedDraft.completionNote, 'Kurul notu');

    // Kopyalama eski taslağı değiştirmemeli; yeni başvuru oturumuna veri sızmamalı.
    expect(initialDraft.applicationForm, isNull);
    expect(initialDraft.householdStatus, isNull);
    expect(initialDraft.completionNote, isEmpty);
  });
}
