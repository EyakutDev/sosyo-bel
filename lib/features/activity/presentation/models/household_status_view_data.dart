/// Hane Durumu ekranındaki tek bir saha sorusunu tanımlar.
class HouseholdQuestionViewData {
  const HouseholdQuestionViewData({
    required this.id,
    required this.label,
    required this.options,
  });

  final String id;
  final String label;
  final List<String> options;
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
  });

  final Map<String, String> answers;
  final List<HouseholdPhotoViewData> photos;
  final bool saveToBeneficiaryDirectory;
}

/// Fotoğraf sınırını ekran ve ileride eklenecek API katmanı için merkezileştirir.
abstract final class HouseholdPhotoPolicy {
  static const maxPhotoCount = 15;
  static const maxPhotoMessage = 'En fazla 15 hane fotoğrafı ekleyebilirsiniz.';
}
