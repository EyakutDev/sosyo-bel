import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/activity/presentation/fixtures/household_status_design_fixture.dart';
import 'package:sosyo_bel/features/activity/presentation/household_status_page.dart';

void main() {
  runApp(const _HouseholdStatusPreviewApp());
}

/// Hane Durumu ekranını gerçek akıştan bağımsız görsel olarak doğrulamak için
/// kullanılan geliştirme giriş noktasıdır; üretim uygulamasına dahil edilmez.
class _HouseholdStatusPreviewApp extends StatelessWidget {
  const _HouseholdStatusPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: HouseholdStatusPage(
        initialStage: HouseholdStatusStage.photos,
        initialPhotos: HouseholdStatusDesignFixture.previewPhotos,
        onBack: _ignore,
        onContinue: (_) {},
        onCapturePhoto: _emptyCapture,
      ),
    );
  }
}

void _ignore() {}

Future<Never?> _emptyCapture() async => null;
