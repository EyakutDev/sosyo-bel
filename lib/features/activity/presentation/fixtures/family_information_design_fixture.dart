import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';

/// Figma'daki Aile Bilgileri örneklerini göstermek ve test etmek için kullanılır.
/// Bu kişiler gerçek vatandaş verisi değildir; manuel aile formunun başlangıç
/// görünümünü ve testlerini destekleyen tasarım örnekleridir.
abstract final class FamilyInformationDesignFixture {
  static const family = FamilyInformationViewData(
    members: [
      FamilyMemberViewData(
        fullName: 'Ahmet YILMAZ',
        relationship: 'Baba',
        age: '63',
      ),
      FamilyMemberViewData(
        fullName: 'Emel YILMAZ',
        relationship: 'Eş',
        age: '50',
        details: FamilyMemberDetailsViewData(
          disabilityStatus: 'Yok',
          employmentStatus: 'Çalışmıyor',
          educationStatus: 'İlk Öğretim Terk',
          vitalStatus: 'Sağ',
        ),
      ),
      FamilyMemberViewData(
        fullName: 'Sercan YILMAZ',
        relationship: 'Çocuk',
        age: '15',
      ),
      FamilyMemberViewData(
        fullName: 'Sevinc YILMAZ',
        relationship: 'Çocuk',
        age: '12',
      ),
      FamilyMemberViewData(
        fullName: 'Mehmet YILMAZ',
        relationship: 'Çocuk',
        age: '8',
      ),
    ],
  );
}
