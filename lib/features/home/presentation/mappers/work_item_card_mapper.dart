import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';
import 'package:sosyo_bel/features/home/domain/work_item.dart';
import 'package:sosyo_bel/features/home/presentation/models/application_card_view_data.dart';

/// Birleşik API modelini mevcut Figma kartının sunum verisine dönüştürür.
abstract final class WorkItemCardMapper {
  static ApplicationCardViewData toViewData(WorkItem item) {
    final status = _status(item);
    return ApplicationCardViewData(
      applicationNumber: item.applicationNumber,
      fullName: item.applicantFullName ?? 'Ad soyad bilgisi bulunmuyor',
      date: _formatDate(item.activityAtUtc),
      addressLine1: item.address ?? 'Adres bilgisi bulunmuyor',
      statusLabel: status.label,
      statusColor: status.color,
    );
  }

  static _WorkItemStatusView _status(WorkItem item) {
    if (item.statusCode == 'IPTAL') {
      return const _WorkItemStatusView('İptal', AppColors.statusRejected);
    }
    if (item.statusCode == 'REDDEDILDI') {
      return const _WorkItemStatusView('Reddedildi', AppColors.statusRejected);
    }
    if (item.isCompleted) {
      return const _WorkItemStatusView('Tamamlandı', AppColors.statusApproved);
    }

    return switch (item.statusCode) {
      'TASLAK' => const _WorkItemStatusView('Taslak', AppColors.statusDraft),
      'KURUL_BEKLIYOR' => const _WorkItemStatusView(
        'Beklemede',
        AppColors.statusBoard,
      ),
      'BASLADI' ||
      'ISLEMDE' => const _WorkItemStatusView('İşlemde', AppColors.statusDraft),
      'BILINMEYEN' => const _WorkItemStatusView(
        'Durum bilinmiyor',
        AppColors.statusBoard,
      ),
      _ => const _WorkItemStatusView('Bekliyor', AppColors.statusBoard),
    };
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${_twoDigits(local.day)}.${_twoDigits(local.month)}.${local.year}';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _WorkItemStatusView {
  const _WorkItemStatusView(this.label, this.color);

  final String label;
  final Color color;
}
