/// Sunucudaki kararlı kod ile ekranda gösterilecek etiketi birlikte taşır.
/// Etiket değişiklikleri kaydedilen API kodunu etkilemez.
final class ApplicationReferenceOption {
  const ApplicationReferenceOption({required this.code, required this.label});

  final String code;
  final String label;

  factory ApplicationReferenceOption.fromJson(Map<String, dynamic> json) {
    return ApplicationReferenceOption(
      code: _requiredString(json, 'code'),
      label: _requiredString(json, 'label'),
    );
  }
}

final class HouseholdQuestionOptionReference {
  const HouseholdQuestionOptionReference({
    required this.code,
    required this.label,
    required this.order,
  });

  final String code;
  final String label;
  final int order;

  factory HouseholdQuestionOptionReference.fromJson(Map<String, dynamic> json) {
    return HouseholdQuestionOptionReference(
      code: _requiredString(json, 'code'),
      label: _requiredString(json, 'label'),
      order: _requiredInt(json, 'order'),
    );
  }
}

final class HouseholdQuestionReference {
  const HouseholdQuestionReference({
    required this.code,
    required this.label,
    required this.answerTypeCode,
    required this.isRequired,
    required this.order,
    required this.options,
  });

  final String code;
  final String label;
  final String answerTypeCode;
  final bool isRequired;
  final int order;
  final List<HouseholdQuestionOptionReference> options;

  factory HouseholdQuestionReference.fromJson(Map<String, dynamic> json) {
    final options = _requiredList(json, 'options')
        .map(
          (value) => HouseholdQuestionOptionReference.fromJson(
            _requiredMap(value, 'options[]'),
          ),
        )
        .toList(growable: false);
    return HouseholdQuestionReference(
      code: _requiredString(json, 'code'),
      label: _requiredString(json, 'label'),
      answerTypeCode: _requiredString(json, 'answerTypeCode'),
      isRequired: _requiredBool(json, 'isRequired'),
      order: _requiredInt(json, 'order'),
      options: List.unmodifiable(options),
    );
  }
}

final class ApplicationReferenceCatalog {
  const ApplicationReferenceCatalog({
    required this.helpTypes,
    required this.disabilityStatuses,
    required this.relationships,
    required this.employmentStatuses,
    required this.educationStatuses,
    required this.vitalStatuses,
    required this.householdQuestions,
  });

  final List<ApplicationReferenceOption> helpTypes;
  final List<ApplicationReferenceOption> disabilityStatuses;
  final List<ApplicationReferenceOption> relationships;
  final List<ApplicationReferenceOption> employmentStatuses;
  final List<ApplicationReferenceOption> educationStatuses;
  final List<ApplicationReferenceOption> vitalStatuses;
  final List<HouseholdQuestionReference> householdQuestions;

  factory ApplicationReferenceCatalog.fromJson(Map<String, dynamic> json) {
    return ApplicationReferenceCatalog(
      helpTypes: _readOptions(json, 'helpTypes'),
      disabilityStatuses: _readOptions(json, 'disabilityStatuses'),
      relationships: _readOptions(json, 'relationships'),
      employmentStatuses: _readOptions(json, 'employmentStatuses'),
      educationStatuses: _readOptions(json, 'educationStatuses'),
      vitalStatuses: _readOptions(json, 'vitalStatuses'),
      householdQuestions: List.unmodifiable(
        _requiredList(json, 'householdQuestions').map(
          (value) => HouseholdQuestionReference.fromJson(
            _requiredMap(value, 'householdQuestions[]'),
          ),
        ),
      ),
    );
  }

  static List<ApplicationReferenceOption> _readOptions(
    Map<String, dynamic> json,
    String key,
  ) {
    return List.unmodifiable(
      _requiredList(json, key).map(
        (value) =>
            ApplicationReferenceOption.fromJson(_requiredMap(value, '$key[]')),
      ),
    );
  }
}

abstract interface class ApplicationReferenceRepository {
  Future<ApplicationReferenceCatalog> getCatalog();

  /// Belediye veya kullanıcı oturumu değiştiğinde önceki kapsamın verisini atar.
  void clearCache();
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key alanı eksik veya geçersiz.');
  }
  return value.trim();
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || value.toInt() != value || value < 0) {
    throw FormatException('$key alanı eksik veya geçersiz.');
  }
  return value.toInt();
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key alanı geçersiz.');
  return value;
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('$key alanı geçersiz.');
  return value;
}

Map<String, dynamic> _requiredMap(Object? value, String field) {
  if (value is! Map) throw FormatException('$field alanı geçersiz.');
  return Map<String, dynamic>.from(value);
}
