import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/auth/auth_tokens.dart';
import 'package:sosyo_bel/core/auth/token_store.dart';
import 'package:sosyo_bel/core/config/api_configuration.dart';
import 'package:sosyo_bel/core/network/api_client.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/features/activity/presentation/fixtures/citizen_profile_design_fixture.dart';
import 'package:sosyo_bel/features/activity/presentation/fixtures/family_information_design_fixture.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/application/data/remote_application_repository.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

void main() {
  group('RemoteApplicationRepository', () {
    test(
      'ekran taslağını API sözleşmesine çevirip idempotent oluşturur',
      () async {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(201, _applicationResponse()),
        );
        final repository = _repository(adapter);

        final result = await repository.createDraft(
          draft: _draft,
          idempotencyKey: 'create-draft-test-key',
        );

        expect(result.statusCode, 'TASLAK');
        expect(result.rowVersion, 'AAAAAAAAAAE=');
        expect(
          adapter.lastRequest?.uri.path,
          '/sosyo-bel/api/v1/applications/drafts',
        );
        expect(
          adapter.lastRequest?.headers['Idempotency-Key'],
          'create-draft-test-key',
        );
        expect(adapter.lastRequest?.data, {
          'draft': {
            'identityNumber': '12345678901',
            'birthDate': '2002-11-03',
            'phoneNumber': '5345512872',
            'helpTypeCode': 'GIDA',
            'hasDisability': true,
            'disabilityTypeCode': 'ORTOPEDIK',
            'disabilityRate': null,
            'description': 'Başvuru açıklaması',
            'applicantFirstName': null,
            'applicantLastName': null,
            'address': null,
            'fieldInspectionNote': 'Saha notu',
          },
        });
      },
    );

    test('manuel aile ve hane cevaplarını kodlarıyla kaydeder', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          200,
          _applicationResponse(rowVersion: 'AAAAAAAAAAI='),
        ),
      );
      final repository = _repository(adapter);

      final result = await repository.saveFieldData(
        draft: _fieldDraft,
        applicationPublicId: '22222222-2222-2222-2222-222222222222',
        expectedRowVersion: 'AAAAAAAAAAE=',
      );

      expect(result.rowVersion, 'AAAAAAAAAAI=');
      expect(
        adapter.lastRequest?.uri.path,
        '/sosyo-bel/api/v1/applications/'
        '22222222-2222-2222-2222-222222222222/field-data',
      );
      expect(adapter.lastRequest?.data, {
        'expectedRowVersion': 'AAAAAAAAAAE=',
        'familyMembers': [
          {
            'fullName': 'Ayşe Yılmaz',
            'age': 42,
            'relationshipCode': 'DIGER',
            'otherRelationshipDescription': 'Teyze',
            'hasDisability': true,
            'disabilityTypeCode': 'SUREGEN_HASTALIK',
            'disabilityDescription': null,
            'employmentStatusCode': 'CALISIYOR',
            'educationStatusCode': 'LISE',
            'vitalStatusCode': 'SAG',
          },
        ],
        'householdAnswers': [
          {'questionCode': 'MULKIYET_DURUMU', 'optionCode': 'KIRACI'},
          {'questionCode': 'EV_TEMIZLIGI', 'optionCode': 'EVET'},
        ],
        'saveToBeneficiaryDirectory': false,
      });
    });

    test('hane fotoğrafını RowVersion ile multipart gönderir', () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'sosyo-bel-photo-test-',
      );
      try {
        final photo = File('${temporaryDirectory.path}/ev.png');
        await photo.writeAsBytes(const [137, 80, 78, 71, 13, 10, 26, 10]);
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(
            200,
            _applicationResponse(rowVersion: 'AAAAAAAAAAM='),
          ),
        );
        final repository = _repository(adapter);
        final photoDraft = _fieldDraft.copyWith(
          householdStatus: HouseholdStatusDraft(
            answers: _fieldDraft.householdStatus!.answers,
            photos: [HouseholdPhotoViewData.file(photo.path)],
            saveToBeneficiaryDirectory: false,
          ),
        );

        final result = await repository.uploadPhotos(
          draft: photoDraft,
          applicationPublicId: '22222222-2222-2222-2222-222222222222',
          expectedRowVersion: 'AAAAAAAAAAI=',
          idempotencyKey: 'upload-photos-test-key',
        );

        expect(result.rowVersion, 'AAAAAAAAAAM=');
        final formData = adapter.lastRequest?.data as FormData;
        expect(Map<String, String>.fromEntries(formData.fields), {
          'expectedRowVersion': 'AAAAAAAAAAI=',
        });
        expect(formData.files, hasLength(1));
        expect(formData.files.single.key, 'photos');
        expect(formData.files.single.value.filename, 'ev.png');
        expect(formData.files.single.value.contentType.toString(), 'image/png');
        expect(
          adapter.lastRequest?.headers['Idempotency-Key'],
          'upload-photos-test-key',
        );
      } finally {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('RowVersion ile kurula gönderip kilitli cevabı ayrıştırır', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          200,
          _applicationResponse(
            statusCode: 'KURUL_BEKLIYOR',
            isEditable: false,
            rowVersion: 'AAAAAAAAAAI=',
          ),
        ),
      );
      final repository = _repository(adapter);

      final result = await repository.submitToBoard(
        applicationPublicId: '22222222-2222-2222-2222-222222222222',
        expectedRowVersion: 'AAAAAAAAAAE=',
        idempotencyKey: 'submit-board-test-key',
      );

      expect(result.statusCode, 'KURUL_BEKLIYOR');
      expect(result.isEditable, isFalse);
      expect(
        adapter.lastRequest?.uri.path,
        '/sosyo-bel/api/v1/applications/'
        '22222222-2222-2222-2222-222222222222/submit',
      );
      expect(adapter.lastRequest?.data, {'expectedRowVersion': 'AAAAAAAAAAE='});
      expect(
        adapter.lastRequest?.headers['Idempotency-Key'],
        'submit-board-test-key',
      );
    });

    test('geçersiz doğum tarihini ağ çağrısından önce reddeder', () async {
      final adapter = _RecordingAdapter(
        (_) => throw StateError('API çağrılmamalı.'),
      );
      final repository = _repository(adapter);
      final invalidDraft = ApplicationDraft(
        applicationForm: const NewApplicationFormData(
          identityNumber: '12345678901',
          birthDate: '31/02/2002',
          disabilityStatus: 'Yok',
          phoneNumber: '05551234567',
          helpType: 'Gıda Yardımı',
          description: '',
        ),
        citizenProfile: CitizenProfileDesignFixture.profile,
        familyInformation: FamilyInformationDesignFixture.family,
      );

      await expectLater(
        repository.createDraft(
          draft: invalidDraft,
          idempotencyKey: 'create-invalid-test-key',
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

const _draft = ApplicationDraft(
  applicationForm: NewApplicationFormData(
    identityNumber: '12345678901',
    birthDate: '03/11/2002',
    disabilityStatus: 'Ortopedik',
    phoneNumber: '(534)-551-2872',
    helpType: 'Gıda Yardımı',
    description: 'Başvuru açıklaması',
  ),
  citizenProfile: CitizenProfileDesignFixture.profile,
  familyInformation: FamilyInformationDesignFixture.family,
  completionNote: 'Saha notu',
);

const _fieldDraft = ApplicationDraft(
  applicationForm: NewApplicationFormData(
    identityNumber: '12345678901',
    birthDate: '03/11/2002',
    disabilityStatus: 'Ortopedik',
    phoneNumber: '(534)-551-2872',
    helpType: 'Gıda Yardımı',
    description: 'Başvuru açıklaması',
  ),
  citizenProfile: CitizenProfileDesignFixture.profile,
  familyInformation: FamilyInformationViewData(
    members: [
      FamilyMemberViewData(
        fullName: 'Ayşe Yılmaz',
        relationship: 'Teyze',
        age: '42',
        details: FamilyMemberDetailsViewData(
          disabilityStatus: 'Süreğen Hastalık',
          employmentStatus: 'Çalışıyor',
          educationStatus: 'Lise',
          vitalStatus: 'Sağ',
        ),
      ),
    ],
  ),
  householdStatus: HouseholdStatusDraft(
    answers: {'ownership-status': 'Kiracı', 'is-home-clean': 'Evet'},
    photos: [],
    saveToBeneficiaryDirectory: false,
  ),
);

RemoteApplicationRepository _repository(HttpClientAdapter adapter) {
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
  return RemoteApplicationRepository(apiClient);
}

Map<String, dynamic> _applicationResponse({
  String statusCode = 'TASLAK',
  bool isEditable = true,
  String rowVersion = 'AAAAAAAAAAE=',
}) => {
  'applicationPublicId': '22222222-2222-2222-2222-222222222222',
  'applicationNumber': '150',
  'statusCode': statusCode,
  'isEditable': isEditable,
  'rowVersion': rowVersion,
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
    // Gercek HTTP adapteri multipart govdesini tuketir. Test adapteri de akisi
    // tuketerek MultipartFile'in dosya taniticisini kapatmalidir.
    await requestStream?.drain<void>();
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
