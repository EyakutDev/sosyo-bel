import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/branding/municipality_branding.dart';
import 'package:sosyo_bel/core/constants/app_assets.dart';

/// Belediyenin yerel veya sunucudan gelen logosunu tek noktadan gösterir.
///
/// Uzak logo henüz yüklenmediyse ya da hata verirse tasarım boş kalmaz;
/// belediyeye atanmış yerel asset, o da boşsa mevcut demo logosu kullanılır.
class MunicipalityLogo extends StatelessWidget {
  const MunicipalityLogo({
    required this.branding,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.high,
    super.key,
  });

  final MunicipalityBranding branding;
  final BoxFit fit;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final remoteUrl = branding.logoUrl?.trim();

    return Semantics(
      image: true,
      label: '${branding.displayName} logosu',
      child: ExcludeSemantics(
        child: remoteUrl == null || remoteUrl.isEmpty
            ? _buildFallbackLogo()
            : Image.network(
                remoteUrl,
                fit: fit,
                filterQuality: filterQuality,
                gaplessPlayback: true,
                loadingBuilder: (context, child, loadingProgress) {
                  return loadingProgress == null ? child : _buildFallbackLogo();
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallbackLogo();
                },
              ),
      ),
    );
  }

  Widget _buildFallbackLogo() {
    final assetPath = branding.localLogoAssetPath.trim().isEmpty
        ? AppAssets.municipalityAvatar
        : branding.localLogoAssetPath;
    return Image.asset(
      assetPath,
      fit: fit,
      filterQuality: filterQuality,
      gaplessPlayback: true,
    );
  }
}
