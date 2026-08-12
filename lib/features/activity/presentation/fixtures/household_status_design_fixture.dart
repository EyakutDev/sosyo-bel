import 'package:sosyo_bel/core/constants/app_assets.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';

/// Figma fotoğraf ekranının görsel karşılaştırmasında kullanılan örnek içerik.
/// Gerçek hane soruları ve seçenekleri yalnız referans API'sinden gelir.
abstract final class HouseholdStatusDesignFixture {
  /// Fotoğraf durumunun Figma karşılaştırmasında kullanılan altı örnek görsel.
  /// Gerçek uygulama akışı fotoğrafsız başlar.
  static const previewPhotos = <HouseholdPhotoViewData>[
    HouseholdPhotoViewData.asset(AppAssets.householdDesignHouse),
    HouseholdPhotoViewData.asset(AppAssets.householdDesignHouse),
    HouseholdPhotoViewData.asset(AppAssets.householdDesignHouse),
    HouseholdPhotoViewData.asset(AppAssets.householdDesignHouse),
    HouseholdPhotoViewData.asset(AppAssets.householdDesignHouse),
    HouseholdPhotoViewData.asset(AppAssets.householdDesignHouse),
  ];
}
