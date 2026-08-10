/// Bekleyen/Tamamlanmış ekranında gösterilebilen tek bir kullanıcı işidir.
///
/// Kayıt, kullanıcının kendi oluşturduğu bir başvuru olabileceği gibi kullanıcıya
/// atanmış bir saha görevi de olabilir. Bu nedenle [taskPublicId] zorunlu değildir.
class WorkItem {
  const WorkItem({
    required this.applicationPublicId,
    required this.applicationNumber,
    required this.sourceCode,
    required this.statusCode,
    required this.isCompleted,
    required this.isEditable,
    required this.activityAtUtc,
    this.taskPublicId,
    this.applicantFullName,
    this.address,
    this.description,
  });

  final String applicationPublicId;
  final String? taskPublicId;
  final String applicationNumber;
  final String? applicantFullName;
  final String? address;
  final String sourceCode;
  final String statusCode;
  final bool isCompleted;
  final bool isEditable;
  final String? description;
  final DateTime activityAtUtc;

  bool get isAssignedTask => sourceCode == 'ASSIGNED_TASK';

  factory WorkItem.fromJson(Map<String, dynamic> json) {
    final sourceCode = _requiredString(json, 'sourceCode').toUpperCase();
    if (sourceCode != 'ASSIGNED_TASK' && sourceCode != 'OWN_APPLICATION') {
      throw const FormatException('sourceCode alanı geçersiz.');
    }

    return WorkItem(
      applicationPublicId: _requiredString(json, 'applicationPublicId'),
      taskPublicId: _optionalString(json, 'taskPublicId'),
      applicationNumber: _requiredString(json, 'applicationNumber'),
      applicantFullName: _optionalString(json, 'applicantFullName'),
      address: _optionalString(json, 'address'),
      sourceCode: sourceCode,
      statusCode: _requiredString(json, 'statusCode').toUpperCase(),
      isCompleted: _requiredBool(json, 'isCompleted'),
      isEditable: _requiredBool(json, 'isEditable'),
      description: _optionalString(json, 'description'),
      activityAtUtc: _requiredDateTime(json, 'activityAtUtc'),
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

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key alanı geçersiz.');
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key alanı geçersiz.');
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final parsed = DateTime.tryParse(json[key]?.toString() ?? '');
  if (parsed == null) throw FormatException('$key alanı geçersiz.');
  return parsed.toUtc();
}
