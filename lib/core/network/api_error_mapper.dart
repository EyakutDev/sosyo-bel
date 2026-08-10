import 'package:dio/dio.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';

/// Dio hatalarını uygulamanın tek tip [ApiException] modeline dönüştürür.
abstract final class ApiErrorMapper {
  static ApiException fromDio(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          kind: ApiErrorKind.timeout,
          message: 'Sunucu yanıt vermedi. Lütfen tekrar deneyin.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          kind: ApiErrorKind.connection,
          message:
              'Sunucuya bağlanılamadı. İnternet ve sunucu adresini kontrol edin.',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          kind: ApiErrorKind.cancelled,
          message: 'İstek iptal edildi.',
        );
      case DioExceptionType.badResponse:
        return _fromResponse(exception.response);
      case DioExceptionType.badCertificate:
        return const ApiException(
          kind: ApiErrorKind.connection,
          message: 'Sunucunun güvenlik sertifikası doğrulanamadı.',
        );
      case DioExceptionType.unknown:
        return const ApiException(
          kind: ApiErrorKind.unknown,
          message: 'Beklenmeyen bir bağlantı hatası oluştu.',
        );
    }
  }

  static ApiException _fromResponse(Response<dynamic>? response) {
    final statusCode = response?.statusCode;
    final body = _asStringKeyedMap(response?.data);
    final code = _readNonEmptyString(body, 'code');
    final traceId = _readNonEmptyString(body, 'traceId');
    final serverMessage =
        _readNonEmptyString(body, 'title') ??
        _readNonEmptyString(body, 'detail');
    final kind = _kindForStatus(statusCode);

    return ApiException(
      kind: kind,
      statusCode: statusCode,
      code: code,
      traceId: traceId,
      fieldErrors: _readFieldErrors(body['errors']),
      message: serverMessage ?? _defaultMessage(kind),
      responseData: response?.data,
    );
  }

  static ApiErrorKind _kindForStatus(int? statusCode) {
    if (statusCode != null && statusCode >= 500 && statusCode <= 599) {
      return ApiErrorKind.server;
    }

    return switch (statusCode) {
      400 || 422 => ApiErrorKind.validation,
      401 => ApiErrorKind.unauthenticated,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      423 => ApiErrorKind.locked,
      429 => ApiErrorKind.rateLimited,
      _ => ApiErrorKind.unknown,
    };
  }

  static String _defaultMessage(ApiErrorKind kind) => switch (kind) {
    ApiErrorKind.validation => 'Gönderilen bilgiler doğrulanamadı.',
    ApiErrorKind.unauthenticated => 'Oturum geçersiz veya süresi dolmuş.',
    ApiErrorKind.forbidden => 'Bu işlem için yetkiniz bulunmuyor.',
    ApiErrorKind.notFound => 'İstenen kayıt bulunamadı.',
    ApiErrorKind.conflict => 'İşlem mevcut kayıtla çakışıyor.',
    ApiErrorKind.locked => 'Hesap veya kayıt geçici olarak kilitli.',
    ApiErrorKind.rateLimited => 'Çok fazla istek gönderildi. Lütfen bekleyin.',
    ApiErrorKind.server => 'Sunucuda beklenmeyen bir hata oluştu.',
    _ => 'İstek tamamlanamadı.',
  };

  static Map<String, dynamic> _asStringKeyedMap(Object? value) {
    if (value is! Map) {
      return const {};
    }

    return value.map((key, dynamic item) => MapEntry(key.toString(), item));
  }

  static String? _readNonEmptyString(Map<String, dynamic> body, String key) {
    final value = body[key];
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return value.trim();
  }

  static Map<String, List<String>> _readFieldErrors(Object? value) {
    if (value is! Map) {
      return const {};
    }

    final result = <String, List<String>>{};
    for (final entry in value.entries) {
      final messages = entry.value;
      if (messages is List) {
        final parsedMessages = messages
            .whereType<String>()
            .where((message) => message.trim().isNotEmpty)
            .toList(growable: false);
        if (parsedMessages.isNotEmpty) {
          result[entry.key.toString()] = parsedMessages;
        }
      }
    }

    return Map.unmodifiable(result);
  }
}
