import 'package:sosyo_bel/features/activity/presentation/models/citizen_profile_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';

/// Yeni Başvuru ekranında personelin girdiği kesinleşmiş kişi ve talep alanları.
///
/// Tarih ve telefon, kullanıcının ekranda gördüğü biçimde tutulur. Gerçek API
/// sözleşmesi geldiğinde sunucunun beklediği biçime dönüştürme veri katmanında
/// yapılacaktır; bu model sunucu alan adlarını veya formatını varsaymaz.
final class NewApplicationFormData {
  const NewApplicationFormData({
    required this.identityNumber,
    required this.birthDate,
    required this.disabilityStatus,
    required this.phoneNumber,
    required this.helpType,
    required this.description,
  });

  final String identityNumber;
  final String birthDate;
  final String disabilityStatus;
  final String phoneNumber;
  final String helpType;
  final String description;
}

/// Devam eden bir başvurunun ekranlar arasında korunması gereken tek kaynağı.
///
/// Bu sınıf bir API DTO'su değildir. Kimlik doğrulama bilgileri, JSON alanları,
/// sunucu durum kodları ve dosya yükleme ayrıntıları burada tutulmaz. Backend
/// sözleşmesi netleştiğinde repository katmanı bu modeli ilgili DTO'lara
/// dönüştürecektir.
final class ApplicationDraft {
  const ApplicationDraft({
    required this.citizenProfile,
    required this.familyInformation,
    this.applicationForm,
    this.householdStatus,
    this.completionNote = '',
  });

  /// Form henüz geçerli şekilde tamamlanmadıysa `null` kalır.
  final NewApplicationFormData? applicationForm;
  final CitizenProfileViewData citizenProfile;
  final FamilyInformationViewData familyInformation;
  final HouseholdStatusDraft? householdStatus;
  final String completionNote;

  /// Her ekran yalnızca kendi sorumluluğundaki alanı değiştirir; diğer adımlarda
  /// toplanmış bilgiler aynı başvuru taslağında korunur.
  ApplicationDraft copyWith({
    NewApplicationFormData? applicationForm,
    CitizenProfileViewData? citizenProfile,
    FamilyInformationViewData? familyInformation,
    HouseholdStatusDraft? householdStatus,
    String? completionNote,
  }) {
    return ApplicationDraft(
      applicationForm: applicationForm ?? this.applicationForm,
      citizenProfile: citizenProfile ?? this.citizenProfile,
      familyInformation: familyInformation ?? this.familyInformation,
      householdStatus: householdStatus ?? this.householdStatus,
      completionNote: completionNote ?? this.completionNote,
    );
  }
}
