/// Bekleyen/Tamamlanmış ekranında gösterilebilen tek bir kullanıcı işidir.
///
/// Kayıt, kullanıcının kendi oluşturduğu bir başvuru olabileceği gibi kullanıcıya
/// atanmış bir saha görevi de olabilir. Şirket şemasında saha aktivitesinin
/// başvuru bağlantısı olmadığı için iki kimlik de kendi kaynağını temsil eder.
class WorkItem {
  const WorkItem({
    required this.applicationNumber,
    required this.sourceCode,
    required this.statusCode,
    required this.isCompleted,
    required this.isEditable,
    required this.activityAtUtc,
    this.applicationId,
    this.applicationPublicId,
    this.localDraftId,
    this.taskId,
    this.applicantFullName,
    this.address,
    this.description,
    this.isOwnedByCurrentUser = false,
  });

  final int? applicationId;
  final String? applicationPublicId;
  final String? localDraftId;
  final int? taskId;
  final String applicationNumber;
  final String? applicantFullName;
  final String? address;
  final String sourceCode;
  final String statusCode;
  final bool isCompleted;
  final bool isEditable;
  final bool isOwnedByCurrentUser;
  final String? description;
  final DateTime activityAtUtc;

  bool get isAssignedTask => sourceCode == 'ASSIGNED_TASK';

  bool get isSubmittedApplication =>
      sourceCode == 'APPLICATION' || sourceCode == 'OWN_APPLICATION';

  static const localDraftSourceCode = 'LOCAL_DRAFT';

  bool get isLocalDraft => sourceCode == localDraftSourceCode;

  factory WorkItem.fromJson(Map<String, dynamic> json) {
    final sourceCode = _requiredString(json, 'sourceCode').toUpperCase();
    if (sourceCode != 'ASSIGNED_TASK' &&
        sourceCode != 'APPLICATION' &&
        sourceCode != 'OWN_APPLICATION') {
      throw const FormatException('sourceCode alanı geçersiz.');
    }
    final applicationId = _optionalPositiveInt(json, 'applicationId');
    final applicationPublicId = _optionalString(json, 'applicationPublicId');
    final taskId = _optionalPositiveInt(json, 'taskId');
    if (sourceCode == 'APPLICATION' && applicationId == null) {
      throw const FormatException('Başvuru kimliği eksik veya geçersiz.');
    }
    if (sourceCode == 'OWN_APPLICATION' && applicationPublicId == null) {
      throw const FormatException('Başvuru kimliği eksik veya geçersiz.');
    }
    if (sourceCode == 'ASSIGNED_TASK' && taskId == null) {
      throw const FormatException('Görev kimliği eksik veya geçersiz.');
    }

    return WorkItem(
      applicationId: applicationId,
      applicationPublicId: applicationPublicId,
      taskId: taskId,
      applicationNumber: _requiredString(json, 'applicationNumber'),
      applicantFullName: _optionalString(json, 'applicantFullName'),
      address: _optionalString(json, 'address'),
      sourceCode: sourceCode,
      statusCode: _requiredString(json, 'statusCode').toUpperCase(),
      isCompleted: _requiredBool(json, 'isCompleted'),
      isEditable: _requiredBool(json, 'isEditable'),
      isOwnedByCurrentUser: json.containsKey('isOwnedByCurrentUser')
          ? _requiredBool(json, 'isOwnedByCurrentUser')
          : sourceCode == 'OWN_APPLICATION',
      description: _optionalString(json, 'description'),
      activityAtUtc: _requiredDateTime(json, 'activityAtUtc'),
    );
  }
}

int? _optionalPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int || value <= 0) {
    throw FormatException('$key alanı geçersiz.');
  }
  return value;
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
