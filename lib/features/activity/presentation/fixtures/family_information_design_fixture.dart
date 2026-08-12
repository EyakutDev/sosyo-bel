import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';

/// Figma'daki Aile Bilgileri örneklerini göstermek ve test etmek için kullanılır.
/// Bu kişiler gerçek vatandaş verisi değildir; manuel aile formunun başlangıç
/// görünümünü ve testlerini destekleyen tasarım örnekleridir.
abstract final class FamilyInformationDesignFixture {
  static const family = FamilyInformationViewData(
    members: [
      FamilyMemberViewData(
        fullName: 'Ahmet YILMAZ',
        relationshipCode: 'BABA',
        relationship: 'Baba',
        age: '63',
      ),
      FamilyMemberViewData(
        fullName: 'Emel YILMAZ',
        relationshipCode: 'ES',
        relationship: 'Eş',
        age: '50',
        details: FamilyMemberDetailsViewData(
          disabilityStatusCode: 'YOK',
          disabilityStatus: 'Yok',
          employmentStatusCode: 'CALISMIYOR',
          employmentStatus: 'Çalışmıyor',
          educationStatusCode: 'ILKOGRETIM_TERK',
          educationStatus: 'İlk Öğretim Terk',
          vitalStatusCode: 'SAG',
          vitalStatus: 'Sağ',
        ),
      ),
      FamilyMemberViewData(
        fullName: 'Sercan YILMAZ',
        relationshipCode: 'COCUK',
        relationship: 'Çocuk',
        age: '15',
      ),
      FamilyMemberViewData(
        fullName: 'Sevinc YILMAZ',
        relationshipCode: 'COCUK',
        relationship: 'Çocuk',
        age: '12',
      ),
      FamilyMemberViewData(
        fullName: 'Mehmet YILMAZ',
        relationshipCode: 'COCUK',
        relationship: 'Çocuk',
        age: '8',
      ),
    ],
  );
}
