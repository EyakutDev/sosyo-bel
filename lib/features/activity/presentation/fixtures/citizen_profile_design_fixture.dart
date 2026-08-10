import 'package:sosyo_bel/features/activity/presentation/models/citizen_profile_view_data.dart';

/// Yalnızca Figma tasarımını göstermek ve test etmek için kullanılan örnek veri.
/// TCKN, ad, adres ve doğum tarihi dahil hiçbir alan gerçek MERNİS çıktısı değildir.
abstract final class CitizenProfileDesignFixture {
  static const profile = CitizenProfileViewData(
    applicationNumber: '#148',
    fullName: 'Ahmet YILMAZ',
    address: 'Bahçelievler Mahallesi\nAnı Sokak No:9/4',
    phoneNumber: '0555 200 10 20',
    identityNumber: '12345678990',
    birthDate: '01.10.1963',
    maritalStatus: 'Evli',
    childrenCount: '3',
    disabilityStatus: 'Ortopedik (%45)',
    employmentStatus: 'Çalışmıyor',
    educationStatus: 'İlköğretim',
  );
}
