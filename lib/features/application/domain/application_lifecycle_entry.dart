/// Backend'de oluşturulmuş başvurunun yaşam döngüsünü sürdürmek için gereken
/// sunucu kimliği ve eşzamanlılık bilgisidir.
class ApplicationLifecycleEntry {
  const ApplicationLifecycleEntry({
    required this.applicationPublicId,
    required this.applicationNumber,
    required this.statusCode,
    required this.isEditable,
    required this.rowVersion,
  });

  final String applicationPublicId;
  final String applicationNumber;
  final String statusCode;
  final bool isEditable;
  final String rowVersion;

  factory ApplicationLifecycleEntry.fromJson(Map<String, dynamic> json) {
    return ApplicationLifecycleEntry(
      applicationPublicId: _requiredString(json, 'applicationPublicId'),
      applicationNumber: _requiredString(json, 'applicationNumber'),
      statusCode: _requiredString(json, 'statusCode').toUpperCase(),
      isEditable: _requiredBool(json, 'isEditable'),
      rowVersion: _requiredString(json, 'rowVersion'),
    );
  }

  /// Şirketin dbo başvurusu kurula doğrudan gönderildiği için RowVersion üretmez.
  /// Bu fabrika yalnız kilitli atomik gönderim cevabını ayrıştırır.
  factory ApplicationLifecycleEntry.fromCompletedSubmissionJson(
    Map<String, dynamic> json,
  ) {
    final isEditable = _requiredBool(json, 'isEditable');
    if (isEditable) {
      throw const FormatException(
        'Tamamlanmış başvuru düzenlenebilir olarak dönemez.',
      );
    }

    return ApplicationLifecycleEntry(
      applicationPublicId: _requiredString(json, 'applicationPublicId'),
      applicationNumber: _requiredString(json, 'applicationNumber'),
      statusCode: _requiredString(json, 'statusCode').toUpperCase(),
      isEditable: false,
      rowVersion: '',
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key alanı eksik veya geçersiz.');
  }
  return value.trim();
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key alanı geçersiz.');
  return value;
}
