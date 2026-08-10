import 'package:dio/dio.dart';
import 'package:sosyo_bel/core/auth/token_store.dart';
import 'package:sosyo_bel/core/config/api_configuration.dart';
import 'package:sosyo_bel/core/network/api_error_mapper.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';

/// HTTP cevabının gövdesini, durum kodunu ve başlıklarını birlikte taşır.
class ApiResponse<T> {
  const ApiResponse({
    required this.data,
    required this.statusCode,
    required this.headers,
  });

  final T? data;
  final int statusCode;
  final Headers headers;
}

/// Uygulamadaki tüm REST isteklerinin geçtiği ortak HTTP istemcisidir.
///
/// Ortak istemci kullanmak; sunucu adresi, timeout, yetkilendirme ve hata
/// davranışlarının her özellikte aynı kalmasını sağlar.
class ApiClient {
  ApiClient({
    required ApiConfiguration configuration,
    required TokenStore tokenStore,
    Dio? dio,
  }) : _tokenStore = tokenStore,
       _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: configuration.baseUrl,
      connectTimeout: configuration.connectTimeout,
      receiveTimeout: configuration.receiveTimeout,
      sendTimeout: configuration.sendTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: const {Headers.acceptHeader: Headers.jsonContentType},
    );

    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _attachAuthorizationHeader),
    );
  }

  static const skipAuthorizationKey = 'skipAuthorization';
  static const authorizationHeader = 'Authorization';

  final TokenStore _tokenStore;
  final Dio _dio;

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool skipAuthorization = false,
    CancelToken? cancelToken,
  }) => request<T>(
    'GET',
    path,
    queryParameters: queryParameters,
    headers: headers,
    skipAuthorization: skipAuthorization,
    cancelToken: cancelToken,
  );

  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool skipAuthorization = false,
    CancelToken? cancelToken,
  }) => request<T>(
    'POST',
    path,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
    skipAuthorization: skipAuthorization,
    cancelToken: cancelToken,
  );

  Future<ApiResponse<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool skipAuthorization = false,
    CancelToken? cancelToken,
  }) => request<T>(
    'PUT',
    path,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
    skipAuthorization: skipAuthorization,
    cancelToken: cancelToken,
  );

  Future<ApiResponse<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool skipAuthorization = false,
    CancelToken? cancelToken,
  }) => request<T>(
    'PATCH',
    path,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
    skipAuthorization: skipAuthorization,
    cancelToken: cancelToken,
  );

  Future<ApiResponse<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool skipAuthorization = false,
    CancelToken? cancelToken,
  }) => request<T>(
    'DELETE',
    path,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
    skipAuthorization: skipAuthorization,
    cancelToken: cancelToken,
  );

  Future<ApiResponse<T>> request<T>(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool skipAuthorization = false,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.request<T>(
        _relativePath(path),
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: headers,
          extra: {skipAuthorizationKey: skipAuthorization},
        ),
      );
      final statusCode = response.statusCode;
      if (statusCode == null) {
        throw const ApiException(
          kind: ApiErrorKind.invalidResponse,
          message: 'Sunucu geçerli bir HTTP durum kodu döndürmedi.',
        );
      }

      return ApiResponse<T>(
        data: response.data,
        statusCode: statusCode,
        headers: response.headers,
      );
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDio(error);
    }
  }

  Future<void> _attachAuthorizationHeader(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthorizationKey] == true) {
      handler.next(options);
      return;
    }

    try {
      final tokens = await _tokenStore.read();
      if (tokens != null) {
        options.headers[authorizationHeader] = 'Bearer ${tokens.accessToken}';
      }
      handler.next(options);
    } catch (error, stackTrace) {
      // Güvenli depoya erişilemiyorsa isteği kimliksiz göndermek yerine durdururuz.
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  String _relativePath(String path) {
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty) {
      throw ArgumentError.value(path, 'path', 'Endpoint yolu boş olamaz.');
    }

    final uri = Uri.tryParse(trimmedPath);
    if (uri?.hasScheme ?? false) {
      throw ArgumentError.value(
        path,
        'path',
        'Endpoint yolu tam bir sunucu adresi içeremez.',
      );
    }

    // Baştaki slash kaldırılır; böylece IIS sanal dizini base URL içinde korunur.
    return trimmedPath.replaceFirst(RegExp(r'^/+'), '');
  }
}
