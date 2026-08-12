/// Hane Durumu ekranındaki tek bir saha sorusunu tanımlar.
class HouseholdQuestionViewData {
  const HouseholdQuestionViewData({
    required this.id,
    required this.label,
    required this.isRequired,
    required this.options,
  });

  final String id;
  final String label;
  final bool isRequired;
  final List<HouseholdQuestionOptionViewData> options;
}

/// Hane cevabının API'ye gönderilecek kodunu ve kullanıcı etiketini ayırır.
final class HouseholdQuestionOptionViewData {
  const HouseholdQuestionOptionViewData({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

/// Fotoğrafın uygulama varlığından mı, cihaz kamerasından mı geldiğini belirtir.
enum HouseholdPhotoKind { asset, file }

/// Ekranın gösterebildiği tek bir hane fotoğrafı.
class HouseholdPhotoViewData {
  const HouseholdPhotoViewData.asset(this.path)
    : kind = HouseholdPhotoKind.asset;

  const HouseholdPhotoViewData.file(this.path) : kind = HouseholdPhotoKind.file;

  final String path;
  final HouseholdPhotoKind kind;
}

/// Hane Durumu adımında oluşan veriyi sonraki katmana tek parça halinde taşır.
class HouseholdStatusDraft {
  const HouseholdStatusDraft({
    required this.answers,
    required this.photos,
    required this.saveToBeneficiaryDirectory,
    this.replaceRemotePhotosOnSave = false,
  });

  /// Soru kodunu seçilen seçenek koduna bağlar.
  final Map<String, String> answers;
  final List<HouseholdPhotoViewData> photos;
  final bool saveToBeneficiaryDirectory;

  /// Taslak sunucudan açıldıysa boş fotoğraf listesi de anlamlı bir değişikliktir:
  /// kullanıcı bütün mevcut fotoğrafları silmiş olabilir.
  final bool replaceRemotePhotosOnSave;
}

/// Fotoğraf sınırını ekran ve ileride eklenecek API katmanı için merkezileştirir.
abstract final class HouseholdPhotoPolicy {
  static const maxPhotoCount = 15;
  static const maxPhotoMessage = 'En fazla 15 hane fotoğrafı ekleyebilirsiniz.';
}
