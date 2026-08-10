import 'package:sosyo_bel/core/constants/app_assets.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';

/// Figma'da seçenek listeleri bulunmadığı için kullanılan geçici sunum verileri.
///
/// Şirket kesin seçenekleri ilettiğinde ekran kodu yerine yalnızca bu liste
/// güncellenecek. Alanların zorunlu olup olmadığı burada varsayılmaz.
abstract final class HouseholdStatusDesignFixture {
  static const questions = <HouseholdQuestionViewData>[
    HouseholdQuestionViewData(
      id: 'ownership-status',
      label: 'Mülkiyet Durumu',
      options: ['Ev Sahibi', 'Kiracı', 'Lojman', 'Diğer'],
    ),
    HouseholdQuestionViewData(
      id: 'property-type',
      label: 'Mülkün Tipi ?',
      options: ['Apartman Dairesi', 'Müstakil Ev', 'Gecekondu', 'Diğer'],
    ),
    HouseholdQuestionViewData(
      id: 'is-home-clean',
      label: 'Ev Temiz mi?',
      options: ['Evet', 'Hayır'],
    ),
    HouseholdQuestionViewData(
      id: 'shelter-condition',
      label: 'Barındığın Yeri Durumu?',
      options: ['İyi', 'Orta', 'Kötü'],
    ),
    HouseholdQuestionViewData(
      id: 'household-goods',
      label: 'Evdeki Eşyalar',
      options: ['Yeterli', 'Kısmen Yeterli', 'Yetersiz'],
    ),
  ];

  /// Fotoğraf durumunun Figma karşılaştırmasında kullanılan altı örnek görsel.
  ///
  /// Gerçek uygulama akışı boş başlar; bu liste yalnızca önizleme ve test içindir.
  static const previewPhotos = <HouseholdPhotoViewData>[
    HouseholdPhotoViewData.asset(AppAssets.householdDesignHouse),
    HouseholdPhotoViewData.asset(AppAssets.householdDesignHouse),
    HouseholdPhotoViewData.asset(AppAssets.householdDesignHouse),
    HouseholdPhotoViewData.asset(AppAssets.householdDesignHouse),
    HouseholdPhotoViewData.asset(AppAssets.householdDesignHouse),
    HouseholdPhotoViewData.asset(AppAssets.householdDesignHouse),
  ];
}
