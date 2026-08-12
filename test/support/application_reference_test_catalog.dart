import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';

/// Widget ve repository testlerinin API'den gelmiş gibi kullandığı kontrollü
/// katalog. Üretim kodu bu dosyaya bağımlı değildir.
const applicationReferenceTestCatalog = ApplicationReferenceCatalog(
  helpTypes: [
    ApplicationReferenceOption(code: 'GIDA', label: 'Gıda Yardımı'),
    ApplicationReferenceOption(code: 'NAKDI', label: 'Nakdi Yardım'),
  ],
  disabilityStatuses: [
    ApplicationReferenceOption(code: 'YOK', label: 'Yok'),
    ApplicationReferenceOption(code: 'ORTOPEDIK', label: 'Ortopedik'),
    ApplicationReferenceOption(
      code: 'SUREGEN_HASTALIK',
      label: 'Süreğen Hastalık',
    ),
  ],
  relationships: [
    ApplicationReferenceOption(code: 'ES', label: 'Eş'),
    ApplicationReferenceOption(code: 'BABA', label: 'Baba'),
    ApplicationReferenceOption(code: 'COCUK', label: 'Çocuk'),
    ApplicationReferenceOption(code: 'DIGER', label: 'Diğer'),
  ],
  employmentStatuses: [
    ApplicationReferenceOption(code: 'CALISIYOR', label: 'Çalışıyor'),
    ApplicationReferenceOption(code: 'CALISMIYOR', label: 'Çalışmıyor'),
    ApplicationReferenceOption(code: 'EMEKLI', label: 'Emekli'),
  ],
  educationStatuses: [
    ApplicationReferenceOption(
      code: 'ILKOGRETIM_TERK',
      label: 'İlk Öğretim Terk',
    ),
    ApplicationReferenceOption(code: 'LISE', label: 'Lise'),
    ApplicationReferenceOption(code: 'LISANS', label: 'Lisans'),
  ],
  vitalStatuses: [
    ApplicationReferenceOption(code: 'SAG', label: 'Sağ'),
    ApplicationReferenceOption(code: 'OLU', label: 'Ölü'),
  ],
  householdQuestions: [
    HouseholdQuestionReference(
      code: 'MULKIYET_DURUMU',
      label: 'Mülkiyet Durumu',
      answerTypeCode: 'TEK_SECIM',
      isRequired: true,
      order: 1,
      options: [
        HouseholdQuestionOptionReference(
          code: 'EV_SAHIBI',
          label: 'Ev Sahibi',
          order: 1,
        ),
        HouseholdQuestionOptionReference(
          code: 'KIRACI',
          label: 'Kiracı',
          order: 2,
        ),
      ],
    ),
    HouseholdQuestionReference(
      code: 'MULK_TIPI',
      label: 'Mülkün Tipi ?',
      answerTypeCode: 'TEK_SECIM',
      isRequired: true,
      order: 2,
      options: [
        HouseholdQuestionOptionReference(
          code: 'APARTMAN_DAIRESI',
          label: 'Apartman Dairesi',
          order: 1,
        ),
      ],
    ),
    HouseholdQuestionReference(
      code: 'EV_TEMIZLIGI',
      label: 'Ev Temiz mi?',
      answerTypeCode: 'TEK_SECIM',
      isRequired: true,
      order: 3,
      options: [
        HouseholdQuestionOptionReference(code: 'EVET', label: 'Evet', order: 1),
        HouseholdQuestionOptionReference(
          code: 'HAYIR',
          label: 'Hayır',
          order: 2,
        ),
      ],
    ),
    HouseholdQuestionReference(
      code: 'BARINMA_DURUMU',
      label: 'Barındığın Yeri Durumu?',
      answerTypeCode: 'TEK_SECIM',
      isRequired: true,
      order: 4,
      options: [
        HouseholdQuestionOptionReference(code: 'IYI', label: 'İyi', order: 1),
      ],
    ),
    HouseholdQuestionReference(
      code: 'EV_ESYALARI',
      label: 'Evdeki Eşyalar',
      answerTypeCode: 'TEK_SECIM',
      isRequired: true,
      order: 5,
      options: [
        HouseholdQuestionOptionReference(
          code: 'YETERLI',
          label: 'Yeterli',
          order: 1,
        ),
      ],
    ),
  ],
);

const householdQuestionTestViewData = <HouseholdQuestionViewData>[
  HouseholdQuestionViewData(
    id: 'MULKIYET_DURUMU',
    label: 'Mülkiyet Durumu',
    isRequired: false,
    options: [
      HouseholdQuestionOptionViewData(code: 'EV_SAHIBI', label: 'Ev Sahibi'),
      HouseholdQuestionOptionViewData(code: 'KIRACI', label: 'Kiracı'),
    ],
  ),
  HouseholdQuestionViewData(
    id: 'MULK_TIPI',
    label: 'Mülkün Tipi ?',
    isRequired: false,
    options: [
      HouseholdQuestionOptionViewData(
        code: 'APARTMAN_DAIRESI',
        label: 'Apartman Dairesi',
      ),
    ],
  ),
  HouseholdQuestionViewData(
    id: 'EV_TEMIZLIGI',
    label: 'Ev Temiz mi?',
    isRequired: false,
    options: [
      HouseholdQuestionOptionViewData(code: 'EVET', label: 'Evet'),
      HouseholdQuestionOptionViewData(code: 'HAYIR', label: 'Hayır'),
    ],
  ),
  HouseholdQuestionViewData(
    id: 'BARINMA_DURUMU',
    label: 'Barındığın Yeri Durumu?',
    isRequired: false,
    options: [HouseholdQuestionOptionViewData(code: 'IYI', label: 'İyi')],
  ),
  HouseholdQuestionViewData(
    id: 'EV_ESYALARI',
    label: 'Evdeki Eşyalar',
    isRequired: false,
    options: [
      HouseholdQuestionOptionViewData(code: 'YETERLI', label: 'Yeterli'),
    ],
  ),
];
