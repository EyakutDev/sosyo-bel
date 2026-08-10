/// Vatandaş profili ekranının API'den bağımsız sunum modeli.
/// Entegrasyon katmanı MERNİS veya başka bir kaynaktan gelen veriyi bu tipe çevirir.
final class CitizenProfileViewData {
  const CitizenProfileViewData({
    required this.applicationNumber,
    required this.fullName,
    required this.address,
    required this.phoneNumber,
    required this.identityNumber,
    required this.birthDate,
    required this.maritalStatus,
    required this.childrenCount,
    required this.disabilityStatus,
    required this.employmentStatus,
    required this.educationStatus,
  });

  final String applicationNumber;
  final String fullName;
  final String address;
  final String phoneNumber;
  final String identityNumber;
  final String birthDate;
  final String maritalStatus;
  final String childrenCount;
  final String disabilityStatus;
  final String employmentStatus;
  final String educationStatus;

  CitizenProfileViewData copyWith({
    String? applicationNumber,
    String? fullName,
    String? address,
    String? phoneNumber,
    String? identityNumber,
    String? birthDate,
    String? maritalStatus,
    String? childrenCount,
    String? disabilityStatus,
    String? employmentStatus,
    String? educationStatus,
  }) {
    return CitizenProfileViewData(
      applicationNumber: applicationNumber ?? this.applicationNumber,
      fullName: fullName ?? this.fullName,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      identityNumber: identityNumber ?? this.identityNumber,
      birthDate: birthDate ?? this.birthDate,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      childrenCount: childrenCount ?? this.childrenCount,
      disabilityStatus: disabilityStatus ?? this.disabilityStatus,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      educationStatus: educationStatus ?? this.educationStatus,
    );
  }
}
