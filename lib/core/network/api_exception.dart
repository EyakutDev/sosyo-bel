/// Arayüz ve repository katmanlarının teknik HTTP ayrıntısı bilmeden
/// işleyebileceği standart API hata türleri.
enum ApiErrorKind {
  validation,
  unauthenticated,
  forbidden,
  notFound,
  conflict,
  locked,
  rateLimited,
  server,
  timeout,
  connection,
  cancelled,
  invalidResponse,
  unknown,
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.traceId,
    this.fieldErrors = const {},
    this.responseData,
  });

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final String? traceId;
  final Map<String, List<String>> fieldErrors;

  /// Özelliğe özel hata ayrıntılarının repository katmanında ayrıştırılmasını
  /// sağlar. Sunucu gövdesi doğrudan arayüz katmanına taşınmamalıdır.
  final Object? responseData;

  bool get requiresLogin => kind == ApiErrorKind.unauthenticated;

  @override
  String toString() => 'ApiException(${kind.name}): $message';
}
