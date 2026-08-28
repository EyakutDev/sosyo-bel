import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/auth/auth_tokens.dart';
import 'package:sosyo_bel/core/config/api_configuration.dart';
import 'package:sosyo_bel/core/network/api_client.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/features/auth/data/authentication_session_store.dart';
import 'package:sosyo_bel/features/auth/data/remote_auth_repository.dart';
import 'package:sosyo_bel/features/auth/domain/authentication_session.dart';

void main() {
  group('RemoteAuthRepository', () {
    test(
      'başarılı cevabı ayrıştırır ve tokenları güvenli depoya yazar',
      () async {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(200, _successfulLoginResponse()),
        );
        final tokenStore = _MemoryTokenStore();
        final repository = _repository(adapter, tokenStore);

        final session = await repository.login(
          username: '  personel  ',
          password: 'TestSifresi123!',
        );

        expect(session.user.displayName, 'Test Personeli');
        expect(session.user.username, 'personel');
        expect(tokenStore.tokens?.accessToken, 'access-token');
        expect(adapter.lastRequest?.data, {
          'username': 'personel',
          'password': 'TestSifresi123!',
        });
        expect(
          adapter.lastRequest?.headers[ApiClient.authorizationHeader],
          isNull,
        );
      },
    );

    test('bozuk başarı cevabında token kaydetmez', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {
          'accessToken': 'access-token',
          'accessTokenExpiresAtUtc': '2026-08-09T13:00:00Z',
          'refreshToken': 'refresh-token',
          'refreshTokenExpiresAtUtc': '2026-08-16T12:00:00Z',
        }),
      );
      final tokenStore = _MemoryTokenStore();
      final repository = _repository(adapter, tokenStore);

      expect(
        () => repository.login(username: 'personel', password: 'secret'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiErrorKind.invalidResponse,
          ),
        ),
      );
      expect(tokenStore.tokens, isNull);
    });

    test('geçerli access tokenı ağ çağrısı yapmadan geri yükler', () async {
      final adapter = _RecordingAdapter(
        (_) => throw StateError('Refresh çağrılmamalı.'),
      );
      final sessionStore = _MemoryTokenStore()
        ..session = _storedSession(
          accessTokenExpiresAtUtc: '2026-08-10T13:00:00Z',
          refreshTokenExpiresAtUtc: '2026-08-17T12:00:00Z',
        );
      final repository = _repository(
        adapter,
        sessionStore,
        nowUtc: () => DateTime.utc(2026, 8, 10, 12),
      );

      final restored = await repository.restoreSession();

      expect(restored?.tokens.accessToken, 'access-token');
      expect(adapter.fetchCount, 0);
    });

    test('süresi dolan access tokenı refresh endpointiyle yeniler', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          200,
          _successfulLoginResponse(
            accessToken: 'refreshed-access-token',
            accessTokenExpiresAtUtc: '2026-08-10T13:00:00Z',
            refreshToken: 'rotated-refresh-token',
            refreshTokenExpiresAtUtc: '2026-08-17T12:00:00Z',
          ),
        ),
      );
      final sessionStore = _MemoryTokenStore()
        ..session = _storedSession(
          accessTokenExpiresAtUtc: '2026-08-10T11:00:00Z',
          refreshTokenExpiresAtUtc: '2026-08-17T12:00:00Z',
        );
      final repository = _repository(
        adapter,
        sessionStore,
        nowUtc: () => DateTime.utc(2026, 8, 10, 12),
      );

      final restored = await repository.restoreSession();

      expect(restored?.tokens.accessToken, 'refreshed-access-token');
      expect(sessionStore.tokens?.refreshToken, 'rotated-refresh-token');
      expect(adapter.lastRequest?.uri.path, '/sosyo-bel/api/v1/auth/refresh');
      expect(adapter.lastRequest?.data, {'refreshToken': 'refresh-token'});
      expect(
        adapter.lastRequest?.headers[ApiClient.authorizationHeader],
        isNull,
      );
    });

    test('süresi dolan refresh tokenı temizleyip giriş ister', () async {
      final adapter = _RecordingAdapter(
        (_) => throw StateError('Refresh çağrılmamalı.'),
      );
      final sessionStore = _MemoryTokenStore()
        ..session = _storedSession(
          accessTokenExpiresAtUtc: '2026-08-10T11:00:00Z',
          refreshTokenExpiresAtUtc: '2026-08-10T12:00:00Z',
        );
      final repository = _repository(
        adapter,
        sessionStore,
        nowUtc: () => DateTime.utc(2026, 8, 10, 12),
      );

      expect(await repository.restoreSession(), isNull);
      expect(sessionStore.session, isNull);
      expect(adapter.fetchCount, 0);
    });

    test(
      'backend refresh tokenı reddederse kayıtlı oturumu temizler',
      () async {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(401, {
            'title': 'Oturum geçersiz veya süresi dolmuş.',
            'code': 'invalid_refresh_token',
          }),
        );
        final sessionStore = _MemoryTokenStore()
          ..session = _storedSession(
            accessTokenExpiresAtUtc: '2026-08-10T11:00:00Z',
            refreshTokenExpiresAtUtc: '2026-08-17T12:00:00Z',
          );
        final repository = _repository(
          adapter,
          sessionStore,
          nowUtc: () => DateTime.utc(2026, 8, 10, 12),
        );

        expect(await repository.restoreSession(), isNull);
        expect(sessionStore.session, isNull);
        expect(adapter.fetchCount, 1);
      },
    );

    test(
      'logout refresh tokenı sunucuya gönderip yerel oturumu temizler',
      () async {
        final adapter = _RecordingAdapter(
          (_) => ResponseBody.fromString('', 204),
        );
        final sessionStore = _MemoryTokenStore()
          ..session = _storedSession(
            accessTokenExpiresAtUtc: '2026-08-10T13:00:00Z',
            refreshTokenExpiresAtUtc: '2026-08-17T12:00:00Z',
          );
        final repository = _repository(adapter, sessionStore);

        await repository.logout();

        expect(sessionStore.session, isNull);
        expect(adapter.lastRequest?.uri.path, '/sosyo-bel/api/v1/auth/logout');
        expect(adapter.lastRequest?.data, {'refreshToken': 'refresh-token'});
        expect(
          adapter.lastRequest?.headers[ApiClient.authorizationHeader],
          isNull,
        );
      },
    );

    test(
      'sunucu logout çağrısı başarısız olsa da yerel oturumu temizler',
      () async {
        final adapter = _RecordingAdapter(
          (options) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        );
        final sessionStore = _MemoryTokenStore()
          ..session = _storedSession(
            accessTokenExpiresAtUtc: '2026-08-10T13:00:00Z',
            refreshTokenExpiresAtUtc: '2026-08-17T12:00:00Z',
          );
        final repository = _repository(adapter, sessionStore);

        await expectLater(
          repository.logout(),
          throwsA(
            isA<ApiException>().having(
              (error) => error.kind,
              'kind',
              ApiErrorKind.connection,
            ),
          ),
        );
        expect(sessionStore.session, isNull);
      },
    );

    test(
      'kayıtlı oturum yoksa ağ çağrısı yapmadan temizliği tamamlar',
      () async {
        final adapter = _RecordingAdapter(
          (_) => throw StateError('Logout çağrılmamalı.'),
        );
        final sessionStore = _MemoryTokenStore();
        final repository = _repository(adapter, sessionStore);

        await repository.logout();

        expect(adapter.fetchCount, 0);
        expect(sessionStore.session, isNull);
      },
    );
  });
}

RemoteAuthRepository _repository(
  HttpClientAdapter adapter,
  AuthenticationSessionStore sessionStore, {
  DateTime Function()? nowUtc,
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  final apiClient = ApiClient(
    configuration: ApiConfiguration.fromEnvironment(
      platform: TargetPlatform.android,
      configuredBaseUrl: 'https://api.example.com/sosyo-bel',
      requireHttps: true,
    ),
    tokenStore: sessionStore,
    dio: dio,
  );
  return RemoteAuthRepository(
    apiClient: apiClient,
    sessionStore: sessionStore,
    nowUtc: nowUtc,
  );
}

Map<String, dynamic> _successfulLoginResponse({
  String accessToken = 'access-token',
  String accessTokenExpiresAtUtc = '2026-08-09T13:00:00Z',
  String refreshToken = 'refresh-token',
  String refreshTokenExpiresAtUtc = '2026-08-16T12:00:00Z',
}) => {
  'accessToken': accessToken,
  'accessTokenExpiresAtUtc': accessTokenExpiresAtUtc,
  'refreshToken': refreshToken,
  'refreshTokenExpiresAtUtc': refreshTokenExpiresAtUtc,
  'user': {
    'userId': 'user-1',
    'username': 'personel',
    'email': 'test@belediye.com',
    'displayName': 'Test Personeli',
    'roles': ['Personel'],
  },
};

AuthenticationSession _storedSession({
  required String accessTokenExpiresAtUtc,
  required String refreshTokenExpiresAtUtc,
}) => AuthenticationSession.fromJson(
  _successfulLoginResponse(
    accessTokenExpiresAtUtc: accessTokenExpiresAtUtc,
    refreshTokenExpiresAtUtc: refreshTokenExpiresAtUtc,
  ),
);

ResponseBody _jsonResponse(int statusCode, Object body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._responseFactory);

  final ResponseBody Function(RequestOptions options) _responseFactory;
  RequestOptions? lastRequest;
  int fetchCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount += 1;
    lastRequest = options;
    return _responseFactory(options);
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStore implements AuthenticationSessionStore {
  AuthenticationSession? session;

  AuthTokens? get tokens => session?.tokens;

  @override
  Future<void> clear() async {
    session = null;
  }

  @override
  Future<AuthTokens?> read() async => session?.tokens;

  @override
  Future<AuthenticationSession?> readSession() async => session;

  @override
  Future<void> save(AuthTokens tokens) async {
    final current = session;
    if (current != null) {
      session = current.copyWith(tokens: tokens);
    }
  }

  @override
  Future<void> saveSession(AuthenticationSession session) async {
    this.session = session;
  }
}
