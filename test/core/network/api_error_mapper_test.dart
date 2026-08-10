import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/network/api_error_mapper.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';

void main() {
  group('ApiErrorMapper', () {
    test(
      'doğrulama cevabındaki alan hatalarını ve traceId bilgisini korur',
      () {
        final mapped = ApiErrorMapper.fromDio(
          _badResponse(
            400,
            data: {
              'title': 'Doğrulama başarısız.',
              'code': 'validation_error',
              'traceId': 'trace-123',
              'errors': {
                'email': ['E-posta zorunludur.'],
              },
            },
          ),
        );

        expect(mapped.kind, ApiErrorKind.validation);
        expect(mapped.message, 'Doğrulama başarısız.');
        expect(mapped.code, 'validation_error');
        expect(mapped.traceId, 'trace-123');
        expect(mapped.fieldErrors['email'], ['E-posta zorunludur.']);
      },
    );

    test('401 cevabını yeniden giriş gerektiren hata olarak işaretler', () {
      final mapped = ApiErrorMapper.fromDio(_badResponse(401));

      expect(mapped.kind, ApiErrorKind.unauthenticated);
      expect(mapped.requiresLogin, isTrue);
    });

    test('timeout hatasını standart kullanıcı mesajına çevirir', () {
      final mapped = ApiErrorMapper.fromDio(
        DioException(
          requestOptions: RequestOptions(path: 'api/v1/applications'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(mapped.kind, ApiErrorKind.timeout);
      expect(mapped.message, contains('yanıt vermedi'));
    });

    test('500 cevabını sunucu hatası olarak sınıflandırır', () {
      final mapped = ApiErrorMapper.fromDio(_badResponse(500));

      expect(mapped.kind, ApiErrorKind.server);
      expect(mapped.statusCode, 500);
    });
  });
}

DioException _badResponse(int statusCode, {Object? data}) {
  final requestOptions = RequestOptions(path: 'api/v1/test');
  return DioException(
    requestOptions: requestOptions,
    response: Response<Object?>(
      requestOptions: requestOptions,
      statusCode: statusCode,
      data: data,
    ),
    type: DioExceptionType.badResponse,
  );
}
