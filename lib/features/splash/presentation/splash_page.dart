import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sosyo_bel/core/constants/app_assets.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';

/// Uygulama hazırlanırken Sosyo-Bel markasını sade ve tutarlı biçimde gösterir.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  static const _referenceWidth = 375.0;

  @override
  Widget build(BuildContext context) {
    final scale = (MediaQuery.sizeOf(context).width / _referenceWidth).clamp(
      0.85,
      1.15,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: const Key('splash-page'),
        backgroundColor: AppColors.white,
        body: Center(
          child: Semantics(
            label: 'Sosyo-Bel açılış ekranı',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  AppAssets.splashLogo,
                  key: const Key('splash-logo'),
                  width: 64 * scale,
                  height: 64 * scale,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                SizedBox(width: 13 * scale),
                Text(
                  'Sosyo-Bel',
                  key: const Key('splash-title'),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 24 * scale,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    letterSpacing: -0.35 * scale,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
