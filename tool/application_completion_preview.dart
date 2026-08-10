import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/activity/presentation/application_completion_page.dart';
import 'package:sosyo_bel/features/activity/presentation/fixtures/citizen_profile_design_fixture.dart';
import 'package:sosyo_bel/features/activity/presentation/fixtures/family_information_design_fixture.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

void main() {
  runApp(const _ApplicationCompletionPreviewApp());
}

/// Tamamla ekranını gerçek akıştan bağımsız görsel olarak doğrulamak için
/// kullanılan geliştirme giriş noktasıdır; üretim uygulamasına dahil edilmez.
class _ApplicationCompletionPreviewApp extends StatelessWidget {
  const _ApplicationCompletionPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: ApplicationCompletionPage(
        applicationDraft: const ApplicationDraft(
          citizenProfile: CitizenProfileDesignFixture.profile,
          familyInformation: FamilyInformationDesignFixture.family,
          householdStatus: HouseholdStatusDraft(
            answers: {},
            photos: [],
            saveToBeneficiaryDirectory: false,
          ),
        ),
        onBack: _ignore,
        onSaveDraft: (_) async {},
        onSubmitToBoard: (_) async {},
      ),
    );
  }
}

void _ignore() {}
