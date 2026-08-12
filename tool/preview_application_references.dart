import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';

/// Yalnız `tool/` altındaki görsel önizlemelerde kullanılan kontrollü katalog.
/// Üretim uygulaması bu verilere geri düşmez; gerçek seçenekleri API'den alır.
const previewApplicationReferenceCatalog = ApplicationReferenceCatalog(
  helpTypes: [ApplicationReferenceOption(code: 'GIDA', label: 'Gıda Yardımı')],
  disabilityStatuses: [
    ApplicationReferenceOption(code: 'YOK', label: 'Yok'),
    ApplicationReferenceOption(code: 'ORTOPEDIK', label: 'Ortopedik'),
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
  ],
  educationStatuses: [
    ApplicationReferenceOption(
      code: 'ILKOGRETIM_TERK',
      label: 'İlk Öğretim Terk',
    ),
    ApplicationReferenceOption(code: 'LISE', label: 'Lise'),
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

/// API'deki kod/etiket ayrımını önizleme ekranının sunum modeline taşır.
final previewHouseholdQuestions = previewApplicationReferenceCatalog
    .householdQuestions
    .map(
      (question) => HouseholdQuestionViewData(
        id: question.code,
        label: question.label,
        isRequired: question.isRequired,
        options: question.options
            .map(
              (option) => HouseholdQuestionOptionViewData(
                code: option.code,
                label: option.label,
              ),
            )
            .toList(growable: false),
      ),
    )
    .toList(growable: false);
