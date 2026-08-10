import 'package:image_picker/image_picker.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';

/// Hane fotoğraflarını cihazın yerel kamera arayüzünden alır.
///
/// Bu sınıf kullanıcı arayüzünden ayrı tutulduğu için ileride şirketin dosya
/// servisi veya farklı bir kamera çözümü geldiğinde ekran değişmeden kalır.
class DeviceHouseholdPhotoPicker {
  DeviceHouseholdPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<HouseholdPhotoViewData?> capturePhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      requestFullMetadata: false,
    );

    if (photo == null) {
      return null;
    }
    return HouseholdPhotoViewData.file(photo.path);
  }

  Future<List<HouseholdPhotoViewData>> recoverLostPhotos() async {
    // Android, kamera açıkken uygulama sürecini sonlandırabilir. Resmî
    // image_picker kurtarma API'siyle dönen fotoğrafları kaybetmiyoruz.
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) {
      return const [];
    }
    if (response.exception != null) {
      throw response.exception!;
    }

    final files = response.files ?? [?response.file];
    return files
        .map((file) => HouseholdPhotoViewData.file(file.path))
        .toList(growable: false);
  }
}
