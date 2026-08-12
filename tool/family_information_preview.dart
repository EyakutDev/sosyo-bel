import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/activity/presentation/family_information_page.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';
import 'preview_application_references.dart';

/// Yalnızca geliştirme sırasında Aile Bilgileri ekranını doğrudan açan görsel
/// QA giriş noktasıdır; üretim uygulamasının navigasyonuna dahil edilmez.
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: FamilyInformationPage(
        referenceCatalog: previewApplicationReferenceCatalog,
        onBack: _ignore,
        onContinue: _ignore,
        onUpdateInformation: _ignore,
        onEditMember: _ignoreMember,
      ),
    ),
  );
}

void _ignore() {}

void _ignoreMember(FamilyMemberViewData member) {}
