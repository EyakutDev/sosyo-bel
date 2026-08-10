import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';

/// Uygulama genelinde kullanılan Material tema yapılandırması.
abstract final class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: false,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: AppColors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primarySecondary,
        surface: AppColors.white,
        onPrimary: AppColors.white,
        onSurface: AppColors.neutralDark,
      ),
    );
  }
}
