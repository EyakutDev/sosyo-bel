/// KPS kimlik ve adres sorgularının uygulamanın kullandığı birleşik sonucudur.
/// Ham servis cevabı ve kullanılmayan adres ayrıntıları mobil katmana taşınmaz.
final class KpsProfile {
  const KpsProfile({
    required this.identityNumber,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.fullAddress,
    this.fatherName,
    this.motherName,
    this.birthPlace,
    this.gender,
    this.maritalStatus,
    this.status,
  });

  final String identityNumber;
  final String firstName;
  final String lastName;
  final String birthDate;
  final String fullAddress;
  final String? fatherName;
  final String? motherName;
  final String? birthPlace;
  final String? gender;
  final String? maritalStatus;
  final String? status;

  String get fullName => '$firstName $lastName'.trim();
}

/// KPS endpointinin HTTP ve JSON ayrıntılarını uygulama akışından gizler.
abstract interface class KpsProfileRepository {
  Future<KpsProfile> getProfile({
    required String identityNumber,
    required String birthDate,
  });
}
