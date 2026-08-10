/// Aile Bilgileri ekranının veri kaynağından bağımsız sunum modeli.
///
/// Yakınlar saha personeli tarafından elle girilir. Kalıcı kayıt API'si
/// eklendiğinde sunucu yanıtları yine bu modele dönüştürülecek; ekran kurumsal
/// servislere doğrudan bağlanmayacak.
final class FamilyInformationViewData {
  const FamilyInformationViewData({required this.members});

  final List<FamilyMemberViewData> members;

  FamilyInformationViewData copyWith({List<FamilyMemberViewData>? members}) {
    return FamilyInformationViewData(members: members ?? this.members);
  }
}

/// Aile tablosunda gösterilen tek bir kişi.
final class FamilyMemberViewData {
  const FamilyMemberViewData({
    required this.fullName,
    required this.relationship,
    required this.age,
    this.details,
  });

  final String fullName;
  final String relationship;
  final String age;

  /// Manuel giriş tamamlanmamış eski kayıtlarda ayrıntılar boş olabilir.
  final FamilyMemberDetailsViewData? details;

  FamilyMemberViewData copyWith({
    String? fullName,
    String? relationship,
    String? age,
    FamilyMemberDetailsViewData? details,
  }) {
    return FamilyMemberViewData(
      fullName: fullName ?? this.fullName,
      relationship: relationship ?? this.relationship,
      age: age ?? this.age,
      details: details ?? this.details,
    );
  }
}

/// Açılan aile üyesi satırında gösterilen ek bilgiler.
final class FamilyMemberDetailsViewData {
  const FamilyMemberDetailsViewData({
    required this.disabilityStatus,
    required this.employmentStatus,
    required this.educationStatus,
    required this.vitalStatus,
  });

  final String disabilityStatus;
  final String employmentStatus;
  final String educationStatus;
  final String vitalStatus;
}
