import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/home/presentation/home_page.dart';

import 'preview_work_items_repository.dart';

void main() {
  runApp(const _SubmissionSuccessPreviewApp());
}

/// Kurula gönderim mesajını Bekleyen Liste üzerinde görsel olarak doğrular.
class _SubmissionSuccessPreviewApp extends StatelessWidget {
  const _SubmissionSuccessPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _RepeatingSuccessPreview(),
    );
  }
}

/// Ekran görüntüsü alınırken üç saniyelik üretim mesajının kaybolmaması için
/// yalnızca bu önizlemede ana ekranı belirli aralıklarla yeniden oluşturur.
class _RepeatingSuccessPreview extends StatefulWidget {
  const _RepeatingSuccessPreview();

  @override
  State<_RepeatingSuccessPreview> createState() =>
      _RepeatingSuccessPreviewState();
}

class _RepeatingSuccessPreviewState extends State<_RepeatingSuccessPreview> {
  Timer? _timer;
  var _previewVersion = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => _previewVersion++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomePage(
      key: ValueKey(_previewVersion),
      workItemsRepository: const PreviewWorkItemsRepository(),
      initialSuccessMessage: 'Başvuru başarıyla kurula gönderildi.',
    );
  }
}
