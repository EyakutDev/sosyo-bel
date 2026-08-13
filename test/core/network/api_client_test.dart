import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/auth/auth_tokens.dart';
import 'package:sosyo_bel/core/auth/token_store.dart';
import 'package:sosyo_bel/core/config/api_configuration.dart';
import 'package:sosyo_bel/core/network/api_client.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';

void main() {
  group('ApiClient', () {
    test(
      'IIS alt yolunu korur ve access tokenı Bearer başlığına ekler',
      () async {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(200, {'ok': true}),
        );
        final dio = Dio()..httpClientAdapter = adapter;
        final client = ApiClient(
          configuration: _configuration(),
          tokenStore: _FixedTokenStore(_tokens()),
          dio: dio,
        );

        final response = await client.get<Map<String, dynamic>>(
          '/api/v1/applications',
        );

        expect(response.data, {'ok': true});
        expect(
          adapter.lastRequest?.uri.toString(),
          'https://api.example.com/sosyo-bel/api/v1/applications',
        );
        expect(
          adapter.lastRequest?.headers[ApiClient.authorizationHeader],
          'Bearer access-token',
        );
      },
    );

    test(
      'açık endpoint istendiğinde Authorization başlığı göndermez',
      () async {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(200, {'ok': true}),
        );
        final dio = Dio()..httpClientAdapter = adapter;
        final client = ApiClient(
          configuration: _configuration(),
          tokenStore: _FixedTokenStore(_tokens()),
          dio: dio,
        );

        await client.post<Map<String, dynamic>>(
          'api/v1/auth/login',
          data: {'email': 'test@belediye.com'},
          skipAuthorization: true,
        );

        expect(
          adapter.lastRequest?.headers[ApiClient.authorizationHeader],
          isNull,
        );
      },
    );

    test('başarısız HTTP cevabını ApiException olarak döndürür', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(401, {'title': 'Oturum süresi doldu.'}),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final client = ApiClient(
        configuration: _configuration(),
        tokenStore: _FixedTokenStore(_tokens()),
        dio: dio,
      );

      expect(
        () => client.get<Map<String, dynamic>>('api/v1/auth/me'),
        throwsA(
          isA<ApiException>()
              .having(
                (error) => error.kind,
                'kind',
                ApiErrorKind.unauthenticated,
              )
              .having(
                (error) => error.message,
                'message',
                'Oturum süresi doldu.',
              ),
        ),
      );
    });
    test('süresi dolan access tokenı istekten önce tek kez yeniler', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {'ok': true}),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final tokenStore = _FixedTokenStore(
        AuthTokens(
          accessToken: 'expired-access-token',
          accessTokenExpiresAtUtc: DateTime.utc(2026, 8, 13, 11),
          refreshToken: 'refresh-token',
          refreshTokenExpiresAtUtc: DateTime.utc(2026, 9, 13, 12),
        ),
      );
      final client = ApiClient(
        configuration: _configuration(),
        tokenStore: tokenStore,
        dio: dio,
        nowUtc: () => DateTime.utc(2026, 8, 13, 12),
      );
      var refreshCount = 0;
      client.configureTokenRefresher(() async {
        refreshCount += 1;
        return AuthTokens(
          accessToken: 'refreshed-access-token',
          accessTokenExpiresAtUtc: DateTime.utc(2026, 8, 13, 13),
          refreshToken: 'rotated-refresh-token',
          refreshTokenExpiresAtUtc: DateTime.utc(2026, 9, 13, 12),
        );
      });

      await client.get<Map<String, dynamic>>('api/v1/work-items');

      expect(refreshCount, 1);
      expect(
        adapter.lastRequest?.headers[ApiClient.authorizationHeader],
        'Bearer refreshed-access-token',
      );
    });

    test('eşzamanlı istekler aynı token yenilemesini bekler', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {'ok': true}),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final client = ApiClient(
        configuration: _configuration(),
        tokenStore: _FixedTokenStore(
          AuthTokens(
            accessToken: 'expired-access-token',
            accessTokenExpiresAtUtc: DateTime.utc(2026, 8, 13, 11),
            refreshToken: 'refresh-token',
            refreshTokenExpiresAtUtc: DateTime.utc(2026, 9, 13, 12),
          ),
        ),
        dio: dio,
        nowUtc: () => DateTime.utc(2026, 8, 13, 12),
      );
      final refreshed = Completer<AuthTokens?>();
      final refreshStarted = Completer<void>();
      var refreshCount = 0;
      client.configureTokenRefresher(() {
        refreshCount += 1;
        refreshStarted.complete();
        return refreshed.future;
      });

      final first = client.get<Map<String, dynamic>>('api/v1/work-items');
      final second = client.get<Map<String, dynamic>>('api/v1/references');
      await refreshStarted.future;
      await Future<void>.delayed(Duration.zero);
      expect(refreshCount, 1);

      refreshed.complete(_tokens());
      await Future.wait([first, second]);
      expect(refreshCount, 1);
    });

    test('401 alan GET isteğini yenilenen tokenla bir kez tekrarlar', () async {
      var requestCount = 0;
      final adapter = _RecordingAdapter((_) {
        requestCount += 1;
        return requestCount == 1
            ? _jsonResponse(401, {'title': 'Oturum süresi doldu.'})
            : _jsonResponse(200, {'ok': true});
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final tokenStore = _FixedTokenStore(_tokens());
      final client = ApiClient(
        configuration: _configuration(),
        tokenStore: tokenStore,
        dio: dio,
        nowUtc: () => DateTime.utc(2026, 8, 9, 12),
      );
      var refreshCount = 0;
      client.configureTokenRefresher(() async {
        refreshCount += 1;
        final tokens = AuthTokens(
          accessToken: 'refreshed-access-token',
          accessTokenExpiresAtUtc: DateTime.utc(2026, 8, 14, 13),
          refreshToken: 'rotated-refresh-token',
          refreshTokenExpiresAtUtc: DateTime.utc(2026, 9, 14, 12),
        );
        await tokenStore.save(tokens);
        return tokens;
      });

      final response = await client.get<Map<String, dynamic>>(
        'api/v1/work-items',
      );

      expect(response.data, {'ok': true});
      expect(requestCount, 2);
      expect(refreshCount, 1);
      expect(
        adapter.lastRequest?.headers[ApiClient.authorizationHeader],
        'Bearer refreshed-access-token',
      );
    });

    test(
      'tam sunucu adresi verilerek base URL dışına çıkılmasını engeller',
      () {
        final client = ApiClient(
          configuration: _configuration(),
          tokenStore: _FixedTokenStore(null),
        );

        expect(
          () => client.get<Object>('https://evil.example/api'),
          throwsArgumentError,
        );
      },
    );
  });
}

ApiConfiguration _configuration() => ApiConfiguration.fromEnvironment(
  platform: TargetPlatform.android,
  configuredBaseUrl: 'https://api.example.com/sosyo-bel',
  requireHttps: true,
);

AuthTokens _tokens() => AuthTokens(
  accessToken: 'access-token',
  accessTokenExpiresAtUtc: DateTime.utc(2026, 8, 9, 13),
  refreshToken: 'refresh-token',
  refreshTokenExpiresAtUtc: DateTime.utc(2026, 8, 16, 12),
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

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return _responseFactory(options);
  }

  @override
  void close({bool force = false}) {}
}

class _FixedTokenStore implements TokenStore {
  _FixedTokenStore(this.tokens);

  AuthTokens? tokens;

  @override
  Future<void> clear() async {
    tokens = null;
  }

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> save(AuthTokens tokens) async {
    this.tokens = tokens;
  }
}
