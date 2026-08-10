import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/activity/presentation/household_status_page.dart';
import 'package:sosyo_bel/features/application/presentation/widgets/application_exit_dialog.dart';

void main() {
  runApp(const _ApplicationExitDialogPreviewApp());
}

/// Başvuru çıkış uyarısını Hane Durumu ekranı üzerinde görsel olarak doğrular.
class _ApplicationExitDialogPreviewApp extends StatelessWidget {
  const _ApplicationExitDialogPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _ApplicationExitDialogPreviewPage(),
    );
  }
}

class _ApplicationExitDialogPreviewPage extends StatefulWidget {
  const _ApplicationExitDialogPreviewPage();

  @override
  State<_ApplicationExitDialogPreviewPage> createState() =>
      _ApplicationExitDialogPreviewPageState();
}

class _ApplicationExitDialogPreviewPageState
    extends State<_ApplicationExitDialogPreviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showApplicationExitDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return HouseholdStatusPage(
      onBack: () => showApplicationExitDialog(context),
      onContinue: (_) {},
      onCapturePhoto: () async => null,
    );
  }
}
