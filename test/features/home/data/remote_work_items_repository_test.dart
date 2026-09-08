import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/auth/auth_tokens.dart';
import 'package:sosyo_bel/core/auth/token_store.dart';
import 'package:sosyo_bel/core/config/api_configuration.dart';
import 'package:sosyo_bel/core/network/api_client.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/features/home/data/remote_work_items_repository.dart';

void main() {
  group('RemoteWorkItemsRepository', () {
    test(
      'birleşik iş listesini ayrıştırıp yetkili endpointi çağırır',
      () async {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(200, [_assignedWorkItemJson, _applicationJson]),
        );
        final repository = _repository(adapter);

        final items = await repository.getMyWorkItems(limit: 25);

        expect(items, hasLength(2));
        expect(items.first.applicationNumber, 'B-2026-150');
        expect(items.first.isAssignedTask, isTrue);
        expect(items.first.taskId, 42);
        expect(items.first.applicationPublicId, isNull);
        expect(items.last.taskId, isNull);
        expect(items.last.applicationId, 151);
        expect(items.last.isOwnedByCurrentUser, isTrue);
        expect(items.last.isEditable, isTrue);
        expect(adapter.lastRequest?.uri.path, '/sosyo-bel/api/v1/work-items');
        expect(adapter.lastRequest?.uri.queryParameters['limit'], '25');
        expect(
          adapter.lastRequest?.headers[ApiClient.authorizationHeader],
          'Bearer access-token',
        );
      },
    );

    test(
      'bozuk iş listesi cevabını standart geçersiz cevap hatasına çevirir',
      () async {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(200, [
            {..._applicationJson, 'isCompleted': 'false'},
          ]),
        );
        final repository = _repository(adapter);

        await expectLater(
          repository.getMyWorkItems(),
          throwsA(
            isA<ApiException>().having(
              (error) => error.kind,
              'kind',
              ApiErrorKind.invalidResponse,
            ),
          ),
        );
      },
    );

    test('geçersiz limitte ağ çağrısı yapmaz', () async {
      final adapter = _RecordingAdapter(
        (_) => throw StateError('API çağrılmamalı.'),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.getMyWorkItems(limit: 101),
        throwsArgumentError,
      );
      expect(adapter.fetchCount, 0);
    });
  });
}

RemoteWorkItemsRepository _repository(HttpClientAdapter adapter) {
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
  return RemoteWorkItemsRepository(apiClient);
}

final _assignedWorkItemJson = <String, dynamic>{
  'applicationId': null,
  'applicationPublicId': null,
  'taskId': 42,
  'applicationNumber': 'B-2026-150',
  'applicantFullName': 'Ahmet Yılmaz',
  'address': 'Bahçelievler Mahallesi No: 4',
  'sourceCode': 'ASSIGNED_TASK',
  'statusCode': 'ATANDI',
  'isCompleted': false,
  'isOwnedByCurrentUser': false,
  'isEditable': false,
  'description': 'Saha incelemesi',
  'activityAtUtc': '2026-08-10T09:00:00Z',
};

final _applicationJson = <String, dynamic>{
  'applicationId': 151,
  'applicationPublicId': '33333333-3333-3333-3333-333333333333',
  'taskId': null,
  'applicationNumber': 'B-2026-151',
  'applicantFullName': null,
  'address': null,
  'sourceCode': 'APPLICATION',
  'statusCode': 'KURUL_BEKLIYOR',
  'isCompleted': false,
  'isOwnedByCurrentUser': true,
  'isEditable': true,
  'description': null,
  'activityAtUtc': '2026-08-10T10:00:00Z',
};

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

class _FixedTokenStore implements TokenStore {
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
