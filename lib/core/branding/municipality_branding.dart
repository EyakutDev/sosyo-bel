import 'package:sosyo_bel/core/constants/app_assets.dart';

/// Giriş yapan kullanıcının bağlı olduğu belediyeye ait görsel kimlik.
///
/// Backend hazır olduğunda oturum yanıtındaki belediye kaydı bu modele
/// dönüştürülecek. Sunucu alan adları burada varsayılmaz; eşleme API/repository
/// katmanının sorumluluğunda kalır.
final class MunicipalityBranding {
  const MunicipalityBranding({
    required this.id,
    required this.displayName,
    this.logoUrl,
    this.localLogoAssetPath = AppAssets.municipalityAvatar,
  });

  /// Backend bağlı değilken mevcut tasarımı koruyan varsayılan kimlik.
  static const demo = MunicipalityBranding(
    id: 'demo-municipality',
    displayName: 'Demolar Belediyesi',
  );

  final String id;
  final String displayName;

  /// Şirket servisi logo adresi döndürdüğünde bu alan doldurulur.
  final String? logoUrl;

  /// Belediye bazlı paketleme yapılırsa özel asset; aksi durumda genel yedek.
  final String localLogoAssetPath;
}
