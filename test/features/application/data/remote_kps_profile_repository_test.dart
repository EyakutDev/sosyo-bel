import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/auth/auth_tokens.dart';
import 'package:sosyo_bel/core/auth/token_store.dart';
import 'package:sosyo_bel/core/config/api_configuration.dart';
import 'package:sosyo_bel/core/network/api_client.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/features/application/data/remote_kps_profile_repository.dart';

void main() {
  group('RemoteKpsProfileRepository', () {
    test(
      'kimlik ve doğum tarihini GET query ile gönderip profili okur',
      () async {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(200, _profileResponse()),
        );
        final repository = _repository(adapter);

        final profile = await repository.getProfile(
          identityNumber: '12345678901',
          birthDate: '14/09/1986',
        );

        expect(adapter.lastRequest?.method, 'GET');
        expect(adapter.lastRequest?.uri.path, '/sosyo-bel/api/v1/kps/profile');
        expect(adapter.lastRequest?.queryParameters, {
          'tcKimlikNo': '12345678901',
          'dogumYil': 1986,
          'dogumAy': 9,
          'dogumGun': 14,
        });
        expect(adapter.lastRequest?.data, isNull);
        expect(
          adapter.lastRequest?.headers[ApiClient.authorizationHeader],
          'Bearer access-token',
        );
        expect(profile.fullName, 'ÖRNEK KİŞİ');
        expect(profile.birthDate, '14/09/1986');
        expect(profile.fullAddress, 'ÖRNEK MAH. TEST SK. NO: 1');
      },
    );

    test('başka kişiye ait cevabı geçersiz sayar', () async {
      final adapter = _RecordingAdapter(
        (_) =>
            _jsonResponse(200, _profileResponse(identityNumber: '99999999999')),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.getProfile(
          identityNumber: '12345678901',
          birthDate: '14/09/1986',
        ),
        throwsA(
          isA<ApiException>()
              .having(
                (error) => error.kind,
                'kind',
                ApiErrorKind.invalidResponse,
              )
              .having(
                (error) => error.message,
                'message',
                'KPS profil cevabı geçersiz.',
              ),
        ),
      );
    });

    test('geçersiz tarihi ağ isteği göndermeden reddeder', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, _profileResponse()),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.getProfile(
          identityNumber: '12345678901',
          birthDate: '31/02/1986',
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiErrorKind.validation,
          ),
        ),
      );

      expect(adapter.fetchCount, 0);
    });
  });
}

RemoteKpsProfileRepository _repository(HttpClientAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  final apiClient = ApiClient(
    configuration: ApiConfiguration.fromEnvironment(
      platform: TargetPlatform.android,
      configuredBaseUrl: 'https://api.example.com/sosyo-bel',
      requireHttps: true,
    ),
    tokenStore: _FixedTokenStore(),
    dio: dio,
  );
  return RemoteKpsProfileRepository(apiClient);
}

Map<String, dynamic> _profileResponse({
  String identityNumber = '12345678901',
}) => {
  'identityNumber': identityNumber,
  'firstName': 'ÖRNEK',
  'lastName': 'KİŞİ',
  'fatherName': 'BABA',
  'motherName': 'ANNE',
  'birthDate': '1986-09-14',
  'birthPlace': 'ÖRNEK İL',
  'gender': 'Erkek',
  'maritalStatus': 'Evli',
  'status': 'Açık',
  'fullAddress': 'ÖRNEK MAH. TEST SK. NO: 1',
};

ResponseBody _jsonResponse(int statusCode, Object body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

final class _RecordingAdapter implements HttpClientAdapter {
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

final class _FixedTokenStore implements TokenStore {
  final _tokens = AuthTokens(
    accessToken: 'access-token',
    accessTokenExpiresAtUtc: DateTime.utc(2026, 8, 10, 13),
    refreshToken: 'refresh-token',
    refreshTokenExpiresAtUtc: DateTime.utc(2026, 8, 17, 12),
  );

  @override
  Future<void> clear() async {}

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> save(AuthTokens tokens) async {}
}
