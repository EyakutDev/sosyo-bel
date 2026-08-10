import 'package:flutter/material.dart';

/// Başvuru kartının ekranda göstereceği, API'den bağımsız sunum verisi.
///
/// Backend kesinleştiğinde API modelleri doğrudan widget'lara verilmez; ilgili
/// mapper bu görsel modele dönüştürür. Böylece ekran sunucu teknolojisine
/// bağımlı kalmaz.
class ApplicationCardViewData {
  const ApplicationCardViewData({
    required this.applicationNumber,
    required this.fullName,
    required this.date,
    required this.addressLine1,
    required this.statusColor,
    this.addressLine2,
    this.statusLabel,
  });

  final String applicationNumber;
  final String fullName;
  final String date;
  final String addressLine1;

  /// Tek satırlık genel adreslerde ikinci satır verilmez; gerçek API adresi iki
  /// satır döndürürse kart aynı tasarımı kullanmaya devam eder.
  final String? addressLine2;

  /// Genel kartlarda yalnızca sabit Durum başlığı gösterilir. Gerçek veri
  /// bağlandığında bekleyen/onaylanan gibi değer bu alana verilecektir.
  final String? statusLabel;
  final Color statusColor;
}
