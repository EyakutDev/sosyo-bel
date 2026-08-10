import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/activity/presentation/citizen_profile_page.dart';

/// Yalnızca geliştirme sırasında vatandaş profilini doğrudan açan görsel QA girişi.
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: CitizenProfilePage(
        onBack: _ignoreContinue,
        onContinue: _ignoreContinue,
      ),
    ),
  );
}

void _ignoreContinue() {}
