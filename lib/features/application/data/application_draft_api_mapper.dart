import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

/// Ekran taslagini basvuru API'sinin cekirdek ve saha verisi sozlesmelerine cevirir.
///
/// Esleme tek yerde tutuldugu icin ekrandaki Turkce etiketler degisse bile sunucunun
/// kalici kodlari ekran widget'larina yayilmaz.
abstract final class ApplicationDraftApiMapper {
  static const _helpTypeCodes = <String, String>{
    'Gıda Yardımı': 'GIDA',
    'Nakdi Yardım': 'NAKDI',
    'Yakacak Yardımı': 'YAKACAK',
    'Barınma Yardımı': 'BARINMA',
    'Eğitim Yardımı': 'EGITIM',
    'Sağlık Yardımı': 'SAGLIK',
    'Diğer': 'DIGER',
  };

  static const _disabilityTypeCodes = <String, String>{
    'Ortopedik': 'ORTOPEDIK',
    'Görme': 'GORME',
    'İşitme': 'ISITME',
    'Zihinsel': 'ZIHINSEL',
    'Süreğen Hastalık': 'SUREGEN_HASTALIK',
    'Diğer': 'DIGER',
  };

  static const _relationshipCodes = <String, String>{
    'Eş': 'ES',
    'Anne': 'ANNE',
    'Baba': 'BABA',
    'Çocuk': 'COCUK',
    'Kardeş': 'KARDES',
    'Büyükanne': 'BUYUKANNE',
    'Büyükbaba': 'BUYUKBABA',
    'Torun': 'TORUN',
    'Gelin': 'GELIN',
    'Damat': 'DAMAT',
    'Kayınvalide': 'KAYINVALIDE',
    'Kayınpeder': 'KAYINPEDER',
  };

  static const _employmentCodes = <String, String>{
    'Çalışıyor': 'CALISIYOR',
    'Çalışmıyor': 'CALISMIYOR',
    'Emekli': 'EMEKLI',
  };

  static const _educationCodes = <String, String>{
    'Okuryazar Değil': 'OKURYAZAR_DEGIL',
    'Okuryazar': 'OKURYAZAR',
    'İlkokul': 'ILKOKUL',
    'İlk Öğretim Terk': 'ILKOGRETIM_TERK',
    'Ortaokul': 'ORTAOKUL',
    'Lise': 'LISE',
    'Ön Lisans': 'ON_LISANS',
    'Lisans': 'LISANS',
    'Yüksek Lisans': 'YUKSEK_LISANS',
    'Doktora': 'DOKTORA',
  };

  static const _vitalStatusCodes = <String, String>{'Sağ': 'SAG', 'Ölü': 'OLU'};

  static const _householdQuestionCodes = <String, String>{
    'ownership-status': 'MULKIYET_DURUMU',
    'property-type': 'MULK_TIPI',
    'is-home-clean': 'EV_TEMIZLIGI',
    'shelter-condition': 'BARINMA_DURUMU',
    'household-goods': 'EV_ESYALARI',
  };

  static const _householdOptionCodes = <String, Map<String, String>>{
    'ownership-status': {
      'Ev Sahibi': 'EV_SAHIBI',
      'Kiracı': 'KIRACI',
      'Lojman': 'LOJMAN',
      'Diğer': 'DIGER',
    },
    'property-type': {
      'Apartman Dairesi': 'APARTMAN_DAIRESI',
      'Müstakil Ev': 'MUSTAKIL_EV',
      'Gecekondu': 'GECEKONDU',
      'Diğer': 'DIGER',
    },
    'is-home-clean': {'Evet': 'EVET', 'Hayır': 'HAYIR'},
    'shelter-condition': {'İyi': 'IYI', 'Orta': 'ORTA', 'Kötü': 'KOTU'},
    'household-goods': {
      'Yeterli': 'YETERLI',
      'Kısmen Yeterli': 'KISMEN_YETERLI',
      'Yetersiz': 'YETERSIZ',
    },
  };

  static Map<String, dynamic> toCreateRequest(ApplicationDraft draft) {
    final form = draft.applicationForm;
    if (form == null) {
      throw const FormatException('Başvuru formu tamamlanmamış.');
    }

    final helpTypeCode = _helpTypeCodes[form.helpType];
    if (helpTypeCode == null) {
      throw const FormatException(
        'Yardım türü sunucu koduyla eşleştirilemedi.',
      );
    }
    final hasDisability = form.disabilityStatus != 'Yok';
    final disabilityTypeCode = hasDisability
        ? _disabilityTypeCodes[form.disabilityStatus]
        : null;
    if (hasDisability && disabilityTypeCode == null) {
      throw const FormatException('Engel türü sunucu koduyla eşleştirilemedi.');
    }

    return {
      'draft': {
        'identityNumber': _digitsOnly(form.identityNumber),
        'birthDate': _toIsoDate(form.birthDate),
        'phoneNumber': _normalizePhone(form.phoneNumber),
        'helpTypeCode': helpTypeCode,
        'hasDisability': hasDisability,
        'disabilityTypeCode': disabilityTypeCode,
        'disabilityRate': null,
        'description': _optionalText(form.description),
        // Profil ad ve adresi henuz gercek MERNIS/KPS cevabi degildir.
        'applicantFirstName': null,
        'applicantLastName': null,
        'address': null,
        'fieldInspectionNote': _optionalText(draft.completionNote),
      },
    };
  }

  static Map<String, dynamic> toFieldDataRequest(
    ApplicationDraft draft, {
    required String expectedRowVersion,
  }) {
    final familyMembers = draft.familyInformation.members
        .map((member) {
          final details = member.details;
          if (details == null) {
            throw FormatException(
              '${member.fullName} için aile ayrıntıları tamamlanmamış.',
            );
          }
          final age = int.tryParse(member.age.trim());
          if (age == null) {
            throw FormatException(
              '${member.fullName} için yaş bilgisi geçersiz.',
            );
          }

          final relationshipCode = _relationshipCodes[member.relationship];
          final employmentCode = _requiredCode(
            _employmentCodes,
            details.employmentStatus,
            'Çalışma durumu',
          );
          final educationCode = _requiredCode(
            _educationCodes,
            details.educationStatus,
            'Eğitim durumu',
          );
          final vitalStatusCode = _requiredCode(
            _vitalStatusCodes,
            details.vitalStatus,
            'Yaşam durumu',
          );
          final disabilityText = details.disabilityStatus.trim();
          final hasDisability = disabilityText.toLowerCase() != 'yok';
          final disabilityTypeCode = hasDisability
              ? (_disabilityTypeCodes[disabilityText] ?? 'DIGER')
              : null;

          return <String, dynamic>{
            'fullName': member.fullName.trim(),
            'age': age,
            'relationshipCode': relationshipCode ?? 'DIGER',
            'otherRelationshipDescription': relationshipCode == null
                ? member.relationship.trim()
                : null,
            'hasDisability': hasDisability,
            'disabilityTypeCode': disabilityTypeCode,
            'disabilityDescription':
                hasDisability &&
                    !_disabilityTypeCodes.containsKey(disabilityText)
                ? disabilityText
                : null,
            'employmentStatusCode': employmentCode,
            'educationStatusCode': educationCode,
            'vitalStatusCode': vitalStatusCode,
          };
        })
        .toList(growable: false);

    final householdAnswers = <Map<String, String>>[];
    final household = draft.householdStatus;
    if (household != null) {
      for (final answer in household.answers.entries) {
        final questionCode = _householdQuestionCodes[answer.key];
        final optionCode = _householdOptionCodes[answer.key]?[answer.value];
        if (questionCode == null || optionCode == null) {
          throw FormatException(
            'Hane cevabı sunucu koduyla eşleştirilemedi: ${answer.key}',
          );
        }
        householdAnswers.add({
          'questionCode': questionCode,
          'optionCode': optionCode,
        });
      }
    }

    return {
      'expectedRowVersion': expectedRowVersion,
      'familyMembers': familyMembers,
      'householdAnswers': householdAnswers,
      'saveToBeneficiaryDirectory':
          household?.saveToBeneficiaryDirectory ?? false,
    };
  }

  static String _requiredCode(
    Map<String, String> codes,
    String value,
    String fieldName,
  ) {
    final code = codes[value.trim()];
    if (code == null) {
      throw FormatException('$fieldName sunucu koduyla eşleştirilemedi.');
    }
    return code;
  }

  static String _toIsoDate(String value) {
    final match = RegExp(
      r'^(\d{2})[./](\d{2})[./](\d{4})$',
    ).firstMatch(value.trim());
    if (match == null) throw const FormatException('Doğum tarihi geçersiz.');
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw const FormatException('Doğum tarihi geçersiz.');
    }
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _normalizePhone(String value) {
    var digits = _digitsOnly(value);
    if (digits.startsWith('90') && digits.length == 12) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }
    return digits;
  }

  static String _digitsOnly(String value) =>
      value.replaceAll(RegExp(r'\D'), '');

  static String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
