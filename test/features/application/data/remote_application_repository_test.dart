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
import 'package:sosyo_bel/features/application/domain/kps_profile.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

void main() {
  group('RemoteApplicationRepository', () {
    test(
      'tamamlanmış başvuruyu ve fotoğrafı tek atomik multipart istekte gönderir',
      () async {
        final temporaryDirectory = await Directory.systemTemp.createTemp(
          'sosyo-bel-atomic-submit-test-',
        );
        try {
          final photo = File.fromUri(
            temporaryDirectory.uri.resolve('hane.jpg'),
          );
          await photo.writeAsBytes(const [255, 216, 255, 217]);
          final adapter = _RecordingAdapter(
            (_) => _jsonResponse(200, {
              'applicationPublicId': '22222222-2222-2222-2222-222222222222',
              'applicationNumber': '#150',
              'statusCode': 'KURUL_BEKLIYOR',
              'isEditable': false,
            }),
          );
          final repository = _repository(adapter);
          final draft = _fieldDraft.copyWith(
            householdStatus: HouseholdStatusDraft(
              answers: _fieldDraft.householdStatus!.answers,
              photos: [HouseholdPhotoViewData.file(photo.path)],
              saveToBeneficiaryDirectory: true,
            ),
            completionNote: 'Kurula iletilecek not',
          );

          final result = await repository.submitCompleted(
            draft: draft,
            idempotencyKey: 'atomic-submit-test-key',
          );

          expect(result.statusCode, 'KURUL_BEKLIYOR');
          expect(result.isEditable, isFalse);
          expect(result.rowVersion, isEmpty);
          expect(
            adapter.lastRequest?.uri.path,
            '/sosyo-bel/api/v1/applications/submit',
          );
          expect(
            adapter.lastRequest?.headers['Idempotency-Key'],
            'atomic-submit-test-key',
          );
          final formData = adapter.lastRequest?.data as FormData;
          expect(formData.files, hasLength(1));
          expect(formData.files.single.key, 'photos');
          expect(formData.files.single.value.filename, 'hane.jpg');
          final fields = Map<String, String>.fromEntries(formData.fields);
          final payload =
              jsonDecode(fields['payload']!) as Map<String, dynamic>;
          expect(payload.keys, {'draft', 'familyMembers', 'householdAnswers'});
          expect(
            (payload['draft'] as Map<String, dynamic>)['fieldInspectionNote'],
            'Kurula iletilecek not',
          );
          expect(payload['familyMembers'], hasLength(1));
          expect(payload['householdAnswers'], hasLength(2));
          expect(payload.containsKey('saveToBeneficiaryDirectory'), isFalse);
        } finally {
          await temporaryDirectory.delete(recursive: true);
        }
      },
    );

    test('geçersiz doğum tarihini ağ çağrısından önce reddeder', () async {
      final adapter = _RecordingAdapter(
        (_) => throw StateError('API çağrılmamalı.'),
      );
      final repository = _repository(adapter);
      final invalidDraft = ApplicationDraft(
        applicationForm: const NewApplicationFormData(
          identityNumber: '12345678901',
          birthDate: '31/02/2002',
          disabilityStatusCode: 'YOK',
          disabilityStatus: 'Yok',
          phoneNumber: '05551234567',
          helpTypeCode: 'GIDA',
          helpType: 'Gıda Yardımı',
          description: '',
        ),
        kpsProfile: const KpsProfile(
          identityNumber: '12345678901',
          firstName: 'ÖRNEK',
          lastName: 'KİŞİ',
          birthDate: '31/02/2002',
          fullAddress: 'ÖRNEK MAH. TEST SK. NO: 1',
        ),
        citizenProfile: CitizenProfileDesignFixture.profile,
        familyInformation: FamilyInformationDesignFixture.family,
      );

      await expectLater(
        repository.submitCompleted(
          draft: invalidDraft,
          idempotencyKey: 'submit-invalid-test-key',
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

    test('gonderilmis basvurunun detaylarini getirir', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, _submittedApplicationDetailsJson),
      );
      final repository = _repository(adapter);

      final details = await repository.getSubmittedDetails(applicationId: 3751);

      expect(details.applicationId, 3751);
      expect(details.applicationNumber, '#3751');
      expect(details.isOwnedByCurrentUser, isTrue);
      expect(details.isEditable, isTrue);
      expect(details.firstName, 'HURIYE');
      expect(details.fieldInspectionNote, 'Saha notu');
      expect(details.familyMembers.single.relationshipCode, 'DIGER');
      expect(details.householdAnswers.single.optionCode, 'KIRACI');
      expect(details.photos.single.urlPath, contains('/hanefotograflari/'));
      expect(adapter.lastRequest?.method, 'GET');
      expect(
        adapter.lastRequest?.uri.path,
        '/sosyo-bel/api/v1/applications/3751',
      );
      expect(
        adapter.lastRequest?.headers[ApiClient.authorizationHeader],
        'Bearer access-token',
      );
    });

    test('gonderilmis basvurunun fotografini yetkili olarak indirir', () async {
      final adapter = _RecordingAdapter(
        (_) => ResponseBody.fromBytes(
          const [1, 2, 3, 4],
          200,
          headers: {
            Headers.contentTypeHeader: ['image/jpeg'],
          },
        ),
      );
      final repository = _repository(adapter);

      final bytes = await repository.getSubmittedPhoto(
        applicationId: 3751,
        photoId: 91,
      );

      expect(bytes, const [1, 2, 3, 4]);
      expect(adapter.lastRequest?.method, 'GET');
      expect(
        adapter.lastRequest?.uri.path,
        '/sosyo-bel/api/v1/applications/3751/photos/91',
      );
    });

    test('yalniz duzenlenebilir alanlari put istegiyle gunceller', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {
          'applicationId': 3751,
          'applicationPublicId': '22222222-2222-2222-2222-222222222222',
          'applicationNumber': '#3751',
          'statusCode': 'KURUL_BEKLIYOR',
          'isEditable': true,
        }),
      );
      final repository = _repository(adapter);
      final draft = _fieldDraft.copyWith(completionNote: 'Guncel saha notu');

      final result = await repository.updateSubmitted(
        applicationId: 3751,
        draft: draft,
      );

      expect(result.applicationId, 3751);
      expect(result.statusCode, 'KURUL_BEKLIYOR');
      expect(result.isEditable, isTrue);
      expect(adapter.lastRequest?.method, 'PUT');
      expect(
        adapter.lastRequest?.uri.path,
        '/sosyo-bel/api/v1/applications/3751',
      );
      final payload = adapter.lastRequest?.data as Map<String, dynamic>;
      expect(payload.keys, {
        'application',
        'familyMembers',
        'householdAnswers',
      });
      final application = payload['application'] as Map<String, dynamic>;
      expect(application['phoneNumber'], '5345512872');
      expect(application['helpTypeCode'], 'GIDA');
      expect(application['hasDisability'], isTrue);
      expect(application['disabilityTypeCode'], 'ORTOPEDIK');
      expect(application['fieldInspectionNote'], 'Guncel saha notu');
      expect(application, isNot(contains('identityNumber')));
      expect(application, isNot(contains('birthDate')));
      expect(application, isNot(contains('applicantFirstName')));
      expect(application, isNot(contains('applicantLastName')));
      expect(application, isNot(contains('address')));
      expect(application, isNot(contains('photos')));
      expect(payload['familyMembers'], hasLength(1));
      expect(payload['householdAnswers'], hasLength(2));
    });

    test(
      'fotograf degisikligini ayni put isteginde multipart gonderir',
      () async {
        final temporaryDirectory = await Directory.systemTemp.createTemp(
          'sosyo-bel-photo-update-test-',
        );
        try {
          final newPhoto = File.fromUri(
            temporaryDirectory.uri.resolve('mutfak.jpg'),
          );
          await newPhoto.writeAsBytes(const [255, 216, 255, 217]);
          final adapter = _RecordingAdapter(
            (_) => _jsonResponse(200, {
              'applicationId': 3751,
              'applicationPublicId': '22222222-2222-2222-2222-222222222222',
              'applicationNumber': '#3751',
              'statusCode': 'KURUL_BEKLIYOR',
              'isEditable': true,
            }),
          );
          final repository = _repository(adapter);
          final draft = _fieldDraft.copyWith(
            householdStatus: HouseholdStatusDraft(
              answers: _fieldDraft.householdStatus!.answers,
              photos: [
                const HouseholdPhotoViewData.remote(
                  path: '/uploads/hanefotograflari/app/salon.jpg',
                  photoId: 91,
                ),
                HouseholdPhotoViewData.file(newPhoto.path),
              ],
              saveToBeneficiaryDirectory: false,
              replaceRemotePhotosOnSave: true,
            ),
          );

          await repository.updateSubmitted(applicationId: 3751, draft: draft);

          final formData = adapter.lastRequest?.data as FormData;
          expect(formData.files, hasLength(1));
          expect(formData.files.single.value.filename, 'mutfak.jpg');
          final fields = Map<String, String>.fromEntries(formData.fields);
          final payload =
              jsonDecode(fields['payload']!) as Map<String, dynamic>;
          expect(payload['retainedPhotoIds'], [91]);
          expect(payload['application'], isA<Map<String, dynamic>>());
          expect(payload['familyMembers'], hasLength(1));
          expect(payload['householdAnswers'], hasLength(2));
        } finally {
          await temporaryDirectory.delete(recursive: true);
        }
      },
    );

    test('bozuk detay cevabini gecersiz sunucu cevabina cevirir', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {
          ..._submittedApplicationDetailsJson,
          'isEditable': 'true',
        }),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.getSubmittedDetails(applicationId: 3751),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiErrorKind.invalidResponse,
          ),
        ),
      );
    });

    test('gecersiz basvuru kimliginde ag cagrisi yapmaz', () async {
      final adapter = _RecordingAdapter(
        (_) => throw StateError('API cagrilmamali.'),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.getSubmittedDetails(applicationId: 0),
        throwsArgumentError,
      );
      await expectLater(
        repository.updateSubmitted(applicationId: -1, draft: _fieldDraft),
        throwsArgumentError,
      );
      expect(adapter.fetchCount, 0);
    });
  });
}

final _submittedApplicationDetailsJson = <String, dynamic>{
  'applicationId': 3751,
  'applicationPublicId': '22222222-2222-2222-2222-222222222222',
  'applicationNumber': '#3751',
  'statusCode': 'KURUL_BEKLIYOR',
  'isOwnedByCurrentUser': true,
  'isEditable': true,
  'applicationDate': '2026-09-07T10:30:00Z',
  'identityNumber': '17611268484',
  'firstName': 'HURIYE',
  'lastName': 'BUCAK',
  'birthDate': '1982-01-01',
  'phoneNumber': '5345512873',
  'helpTypeCode': 'EV_ESYASI',
  'hasDisability': true,
  'disabilityTypeCode': 'SUREGEN_HASTALIK',
  'disabilityRate': null,
  'description': 'Basvuru aciklamasi',
  'fieldInspectionNote': 'Saha notu',
  'address': 'ORDUZU MAH. KATMER SK.',
  'gender': 'Kadin',
  'birthPlace': 'KAHTA',
  'maritalStatus': 'Evli',
  'cancellationDescription': null,
  'cancellationDate': null,
  'familyMembers': [
    {
      'fullName': 'Ayse Yilmaz',
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
  ],
  'photos': [
    {
      'photoId': 91,
      'urlPath':
          '/uploads/hanefotograflari/22222222222222222222222222222222/hane.jpg',
      'description': null,
      'uploadedAt': '2026-09-07T10:31:00Z',
    },
  ],
};

const _fieldDraft = ApplicationDraft(
  applicationForm: NewApplicationFormData(
    identityNumber: '12345678901',
    birthDate: '03/11/2002',
    disabilityStatusCode: 'ORTOPEDIK',
    disabilityStatus: 'Ortopedik',
    phoneNumber: '(534)-551-2872',
    helpTypeCode: 'GIDA',
    helpType: 'Gıda Yardımı',
    description: 'Başvuru açıklaması',
  ),
  kpsProfile: KpsProfile(
    identityNumber: '12345678901',
    firstName: 'ÖRNEK',
    lastName: 'KİŞİ',
    birthDate: '03/11/2002',
    fullAddress: 'ÖRNEK MAH. TEST SK. NO: 1',
  ),
  citizenProfile: CitizenProfileDesignFixture.profile,
  familyInformation: FamilyInformationViewData(
    members: [
      FamilyMemberViewData(
        fullName: 'Ayşe Yılmaz',
        relationshipCode: 'DIGER',
        relationship: 'Teyze',
        age: '42',
        details: FamilyMemberDetailsViewData(
          disabilityStatusCode: 'SUREGEN_HASTALIK',
          disabilityStatus: 'Süreğen Hastalık',
          employmentStatusCode: 'CALISIYOR',
          employmentStatus: 'Çalışıyor',
          educationStatusCode: 'LISE',
          educationStatus: 'Lise',
          vitalStatusCode: 'SAG',
          vitalStatus: 'Sağ',
        ),
      ),
    ],
  ),
  householdStatus: HouseholdStatusDraft(
    answers: {'MULKIYET_DURUMU': 'KIRACI', 'EV_TEMIZLIGI': 'EVET'},
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
