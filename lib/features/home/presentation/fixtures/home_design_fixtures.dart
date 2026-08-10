import 'package:sosyo_bel/core/theme/app_colors.dart';
import 'package:sosyo_bel/features/home/presentation/models/application_card_view_data.dart';

/// Figma ana ekranlarında görünen kişisel veri içermeyen genel kartlar.
///
/// Kart sayıları referans tasarımı korur. API bağlandığında bu dosya üretim veri
/// kaynağı olarak kullanılmayacak; gerçek alanlar mapper üzerinden sağlanacaktır.
abstract final class HomeDesignFixtures {
  static const _genericCard = ApplicationCardViewData(
    applicationNumber: 'Başvuru No',
    fullName: 'İsim Soyisim',
    date: 'Tarih',
    addressLine1: 'Adres',
    statusColor: AppColors.primary,
  );

  static const pending = <ApplicationCardViewData>[
    _genericCard,
    _genericCard,
    _genericCard,
    _genericCard,
  ];

  static const completed = <ApplicationCardViewData>[
    _genericCard,
    _genericCard,
    _genericCard,
    _genericCard,
  ];
}
