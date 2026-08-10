import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/home/presentation/home_page.dart';

import 'preview_work_items_repository.dart';

/// Yalnızca geliştirme sırasında ana ekranı doğrudan açan görsel QA girişi.
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomePage(workItemsRepository: PreviewWorkItemsRepository()),
    ),
  );
}
