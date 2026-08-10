import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/activity/presentation/family_information_editor_page.dart';
import 'package:sosyo_bel/features/activity/presentation/fixtures/family_information_design_fixture.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';

void main() {
  runApp(const _FamilyInformationEditorPreviewApp());
}

/// Manuel aile yönetimi ekranını gerçek cihaz ölçüsünde görsel olarak doğrular.
class _FamilyInformationEditorPreviewApp extends StatefulWidget {
  const _FamilyInformationEditorPreviewApp();

  @override
  State<_FamilyInformationEditorPreviewApp> createState() =>
      _FamilyInformationEditorPreviewAppState();
}

class _FamilyInformationEditorPreviewAppState
    extends State<_FamilyInformationEditorPreviewApp> {
  var _data = FamilyInformationDesignFixture.family;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: FamilyInformationEditorPage(
        data: _data,
        onChanged: (FamilyInformationViewData data) {
          setState(() => _data = data);
        },
      ),
    );
  }
}
