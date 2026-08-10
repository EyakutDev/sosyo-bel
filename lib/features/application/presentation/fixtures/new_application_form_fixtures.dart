/// Yeni başvuru formunda tasarımı ve akışı geliştirebilmek için kullanılan
/// geçici seçenekler.
///
/// Bu değerler şirketin kesin seçenekleri değildir. Backend sözleşmesi
/// netleştiğinde API'den gelen kod/değer listeleriyle değiştirilmelidir.
abstract final class NewApplicationFormFixtures {
  static const disabilityStatuses = <String>[
    'Yok',
    'Ortopedik',
    'Görme',
    'İşitme',
    'Zihinsel',
    'Süreğen Hastalık',
    'Diğer',
  ];

  static const helpTypes = <String>[
    'Gıda Yardımı',
    'Nakdi Yardım',
    'Yakacak Yardımı',
    'Barınma Yardımı',
    'Eğitim Yardımı',
    'Sağlık Yardımı',
    'Diğer',
  ];
}
