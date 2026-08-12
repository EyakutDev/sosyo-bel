import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';

void main() {
  test('referans kataloğunu kod, etiket ve hane sırasıyla okur', () {
    final catalog = ApplicationReferenceCatalog.fromJson({
      'helpTypes': [
        {'code': 'GIDA', 'label': 'Gıda Yardımı'},
      ],
      'disabilityStatuses': [
        {'code': 'YOK', 'label': 'Yok'},
      ],
      'relationships': [
        {'code': 'ES', 'label': 'Eş'},
      ],
      'employmentStatuses': [
        {'code': 'CALISIYOR', 'label': 'Çalışıyor'},
      ],
      'educationStatuses': [
        {'code': 'LISE', 'label': 'Lise'},
      ],
      'vitalStatuses': [
        {'code': 'SAG', 'label': 'Sağ'},
      ],
      'householdQuestions': [
        {
          'code': 'EV_TEMIZLIGI',
          'label': 'Ev Temiz mi?',
          'answerTypeCode': 'TEK_SECIM',
          'isRequired': true,
          'order': 3,
          'options': [
            {'code': 'EVET', 'label': 'Evet', 'order': 1},
          ],
        },
      ],
    });

    expect(catalog.helpTypes.single.code, 'GIDA');
    expect(catalog.helpTypes.single.label, 'Gıda Yardımı');
    expect(catalog.householdQuestions.single.code, 'EV_TEMIZLIGI');
    expect(catalog.householdQuestions.single.options.single.code, 'EVET');
  });

  test('eksik kodu sessizce kabul etmez', () {
    expect(
      () => ApplicationReferenceCatalog.fromJson({
        'helpTypes': [
          {'code': '', 'label': 'Gıda Yardımı'},
        ],
        'disabilityStatuses': [],
        'relationships': [],
        'employmentStatuses': [],
        'educationStatuses': [],
        'vitalStatuses': [],
        'householdQuestions': [],
      }),
      throwsFormatException,
    );
  });
}
