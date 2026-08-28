import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

/// Ekran taslagini basvuru API'sinin cekirdek ve saha verisi sozlesmelerine cevirir.
///
/// Esleme tek yerde tutuldugu icin ekrandaki Turkce etiketler degisse bile sunucunun
/// kalici kodlari ekran widget'larina yayilmaz.
abstract final class ApplicationDraftApiMapper {
  /// Yerel taslağı yeni atomik kurula gönderme endpointinin tek JSON alanına
  /// dönüştürür. Fotoğraf içerikleri repository tarafından multipart eklenir.
  static Map<String, dynamic> toCompletedSubmissionRequest(
    ApplicationDraft draft,
  ) {
    final draftEnvelope = _toDraftEnvelope(draft);
    final fieldData = _toFieldData(draft);
    return {
      'draft': draftEnvelope['draft'],
      'familyMembers': fieldData['familyMembers'],
      'householdAnswers': fieldData['householdAnswers'],
    };
  }

  static Map<String, dynamic> _toDraftEnvelope(ApplicationDraft draft) {
    final form = draft.applicationForm;
    if (form == null) {
      throw const FormatException('Başvuru formu tamamlanmamış.');
    }

    final helpTypeCode = form.helpTypeCode.trim();
    final disabilityStatusCode = form.disabilityStatusCode.trim();
    if (helpTypeCode.isEmpty || disabilityStatusCode.isEmpty) {
      throw const FormatException('Başvuru referans kodları eksik.');
    }
    final hasDisability = disabilityStatusCode != 'YOK';
    final disabilityTypeCode = hasDisability ? disabilityStatusCode : null;
    final kpsProfile = draft.kpsProfile;
    if (kpsProfile == null ||
        kpsProfile.identityNumber != _digitsOnly(form.identityNumber) ||
        _toIsoDate(kpsProfile.birthDate) != _toIsoDate(form.birthDate)) {
      throw const FormatException(
        'KPS profil bilgileri eksik veya form ile uyuşmuyor.',
      );
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
        // Yalnız backend üzerinden doğrulanıp taslağa eklenen KPS alanları yazılır.
        'applicantFirstName': kpsProfile.firstName,
        'applicantLastName': kpsProfile.lastName,
        'address': kpsProfile.fullAddress,
        'fieldInspectionNote': _optionalText(draft.completionNote),
      },
    };
  }

  static Map<String, dynamic> _toFieldData(ApplicationDraft draft) {
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

          final relationshipCode = member.relationshipCode.trim();
          final employmentCode = details.employmentStatusCode.trim();
          final educationCode = details.educationStatusCode.trim();
          final vitalStatusCode = details.vitalStatusCode.trim();
          final disabilityStatusCode = details.disabilityStatusCode.trim();
          if ([
            relationshipCode,
            employmentCode,
            educationCode,
            vitalStatusCode,
            disabilityStatusCode,
          ].any((code) => code.isEmpty)) {
            throw FormatException(
              '${member.fullName} için aile referans kodları eksik.',
            );
          }
          final hasDisability = disabilityStatusCode != 'YOK';

          return <String, dynamic>{
            'fullName': member.fullName.trim(),
            'age': age,
            'relationshipCode': relationshipCode,
            'otherRelationshipDescription': relationshipCode == 'DIGER'
                ? member.relationship.trim()
                : null,
            'hasDisability': hasDisability,
            'disabilityTypeCode': hasDisability ? disabilityStatusCode : null,
            'disabilityDescription': null,
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
        final questionCode = answer.key.trim();
        final optionCode = answer.value.trim();
        if (questionCode.isEmpty || optionCode.isEmpty) {
          throw FormatException(
            'Hane cevabı referans kodları eksik: ${answer.key}',
          );
        }
        householdAnswers.add({
          'questionCode': questionCode,
          'optionCode': optionCode,
        });
      }
    }

    return {
      'familyMembers': familyMembers,
      'householdAnswers': householdAnswers,
    };
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
