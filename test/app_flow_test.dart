import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/app.dart';
import 'package:sosyo_bel/core/auth/auth_tokens.dart';
import 'package:sosyo_bel/features/auth/domain/auth_repository.dart';
import 'package:sosyo_bel/features/auth/domain/authentication_session.dart';
import 'package:sosyo_bel/features/application/domain/application_lifecycle_entry.dart';
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';
import 'package:sosyo_bel/features/application/domain/application_repository.dart';
import 'package:sosyo_bel/features/application/domain/kps_profile.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';
import 'package:sosyo_bel/features/activity/presentation/fixtures/citizen_profile_design_fixture.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/home/domain/work_item.dart';
import 'package:sosyo_bel/features/home/domain/work_items_repository.dart';
import 'support/application_reference_test_catalog.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    AuthRepository? authRepository,
    ApplicationRepository? applicationRepository,
    KpsProfileRepository? kpsProfileRepository,
    WorkItemsRepository? workItemsRepository,
    bool waitForRestore = true,
    bool enterCredentials = true,
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      SosyoBelApp(
        authRepository: authRepository ?? _SuccessfulAuthRepository(),
        applicationRepository:
            applicationRepository ?? _FakeApplicationRepository(),
        applicationReferenceRepository: _FakeApplicationReferenceRepository(),
        kpsProfileRepository:
            kpsProfileRepository ?? _SuccessfulKpsProfileRepository(),
        workItemsRepository: workItemsRepository ?? _EmptyWorkItemsRepository(),
      ),
    );
    if (waitForRestore) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    if (!enterCredentials) return;

    await tester.enterText(
      find.byKey(const Key('login-email-field')),
      'test@belediye.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'TestSifresi123!',
    );
  }

  Future<void> answerRequiredHouseholdQuestions(WidgetTester tester) async {
    const answers = {
      'MULKIYET_DURUMU': 'Ev Sahibi',
      'MULK_TIPI': 'Apartman Dairesi',
      'EV_TEMIZLIGI': 'Evet',
      'BARINMA_DURUMU': 'İyi',
      'EV_ESYALARI': 'Yeterli',
    };

    for (final answer in answers.entries) {
      final dropdown = find.byKey(Key('household-question-${answer.key}'));
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(answer.value).last);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('kayıtlı geçerli oturumla giriş formunu geçip işlemleri açar', (
    tester,
  ) async {
    await pumpApp(
      tester,
      authRepository: _RestoreAuthRepository(() async => _testSession()),
      enterCredentials: false,
    );

    expect(find.text('İşlem Seçimi'), findsOneWidget);
    expect(find.byKey(const Key('login-submit-button')), findsNothing);
  });

  testWidgets(
    'oturum kontrol edilirken mevcut giriş butonunda yüklenme gösterir',
    (tester) async {
      final completer = Completer<AuthenticationSession?>();
      await pumpApp(
        tester,
        authRepository: _RestoreAuthRepository(() => completer.future),
        waitForRestore: false,
        enterCredentials: false,
      );

      expect(find.byKey(const Key('login-loading-indicator')), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-loading-indicator')), findsNothing);
      expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
    },
  );

  testWidgets('girişten sonra işlem seçim ekranını açar', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('İşlem Seçimi'), findsOneWidget);
    expect(find.text('Başvuru Yap'), findsOneWidget);
    expect(find.text('Görevler'), findsOneWidget);
  });

  testWidgets('Görevler mevcut başvuru listelerini açar', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Görevler'));
    await tester.pumpAndSettle();

    expect(find.text('Bekleyen Liste'), findsOneWidget);
    expect(find.text('Tamamlanmış'), findsOneWidget);
  });

  testWidgets('bekleyen taslağı sunucudan yükleyip formda yeniden açar', (
    tester,
  ) async {
    const applicationPublicId = '22222222-2222-2222-2222-222222222222';
    final repository = _FakeApplicationRepository(
      loadedDraft: const LoadedApplicationDraft(
        entry: ApplicationLifecycleEntry(
          applicationPublicId: applicationPublicId,
          applicationNumber: 'B-2026-152',
          statusCode: 'TASLAK',
          isEditable: true,
          rowVersion: 'AAAAAAAAAAE=',
        ),
        draft: ApplicationDraft(
          applicationForm: NewApplicationFormData(
            identityNumber: '12345678901',
            birthDate: '03.11.2002',
            disabilityStatusCode: 'YOK',
            disabilityStatus: 'Yok',
            phoneNumber: '5345512872',
            helpTypeCode: 'GIDA',
            helpType: 'Gıda Yardımı',
            description: 'Geri yüklenen taslak',
          ),
          citizenProfile: CitizenProfileDesignFixture.profile,
          familyInformation: FamilyInformationViewData(members: []),
          householdStatus: HouseholdStatusDraft(
            answers: {},
            photos: [],
            saveToBeneficiaryDirectory: false,
            replaceRemotePhotosOnSave: true,
          ),
        ),
      ),
    );
    final item = WorkItem(
      applicationPublicId: applicationPublicId,
      applicationNumber: 'B-2026-152',
      sourceCode: 'OWN_APPLICATION',
      statusCode: 'TASLAK',
      isCompleted: false,
      isEditable: true,
      activityAtUtc: DateTime.utc(2026, 8, 11, 10),
    );
    await pumpApp(
      tester,
      applicationRepository: repository,
      workItemsRepository: _FixedWorkItemsRepository([item]),
    );

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Görevler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B-2026-152'));
    await tester.pumpAndSettle();

    expect(repository.getCount, 1);
    expect(find.text('Yeni Başvuru'), findsOneWidget);
    expect(find.text('12345678901'), findsOneWidget);
    expect(find.text('Geri yüklenen taslak'), findsOneWidget);
  });

  testWidgets('Başvuru Yap yeni formu açar', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Başvuru Yap'));
    await tester.pumpAndSettle();

    expect(find.text('Yeni Başvuru'), findsOneWidget);
    expect(find.text('Kişi Bilgileri'), findsOneWidget);
    expect(find.text('Talep Bilgileri'), findsOneWidget);
  });

  testWidgets('sistem geri eylemi onaylanınca başvuruyu tamamen kapatır', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Başvuru Yap'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Başvuru Tamamlanmadı'), findsOneWidget);

    await tester.tap(find.byKey(const Key('application-exit-confirm-button')));
    await tester.pumpAndSettle();
    expect(find.text('İşlem Seçimi'), findsOneWidget);
    expect(find.text('Yeni Başvuru'), findsNothing);
  });

  testWidgets('çıkış onaylanınca oturumu kapatıp giriş ekranını açar', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('action-selection-logout-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logout-confirmation-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
    expect(find.text('İşlem Seçimi'), findsNothing);
  });

  testWidgets('Görevlerden geri dönünce işlem seçim ekranını açar', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Görevler'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-back-button')));
    await tester.pumpAndSettle();

    expect(find.text('İşlem Seçimi'), findsOneWidget);
    expect(find.text('Bekleyen Liste'), findsNothing);
  });
  testWidgets('başvuru taslağını Tamamla ekranından Bekleyen Listeye taşır', (
    tester,
  ) async {
    final applicationRepository = _FakeApplicationRepository();
    await pumpApp(tester, applicationRepository: applicationRepository);

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Başvuru Yap'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('new-application-tckn-field')),
      '12345678901',
    );
    await tester.enterText(
      find.byKey(const Key('new-application-birth-date-field')),
      '01.01.1990',
    );
    await tester.enterText(
      find.byKey(const Key('new-application-phone-field')),
      '05551234567',
    );

    final helpDropdownControl = find.byKey(
      const Key('new-application-help-dropdown-control'),
    );
    await tester.ensureVisible(helpDropdownControl);
    await tester.tap(helpDropdownControl);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gıda Yardımı').last);
    await tester.pumpAndSettle();

    final formContinue = find.byKey(
      const Key('new-application-continue-button'),
    );
    await tester.ensureVisible(formContinue);
    await tester.tap(formContinue);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('citizen-profile-back-button')),
      findsOneWidget,
    );
    // İlk formdaki ortak alanlar profil adımında farklı fixture değerleriyle
    // ezilmemeli; aynı ApplicationDraft üzerinden gösterilmelidir.
    expect(find.text('12345678901'), findsOneWidget);
    expect(find.text('01/01/1990'), findsOneWidget);
    expect(find.text('(555)-123-4567'), findsOneWidget);
    expect(find.text('Yok'), findsOneWidget);
    expect(find.text('ÖRNEK KİŞİ'), findsOneWidget);
    expect(find.text('Örnek Mah. Test Sk. No: 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('citizen-profile-back-button')));
    await tester.pumpAndSettle();
    expect(find.text('Başvuru Ekranına Dön'), findsOneWidget);
    expect(
      find.textContaining('Girdiğiniz bilgiler korunacak.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('activity-return-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.text('Yeni Başvuru'), findsOneWidget);
    expect(find.text('12345678901'), findsOneWidget);
    expect(find.text('01/01/1990'), findsOneWidget);
    expect(find.text('(555)-123-4567'), findsOneWidget);

    await tester.ensureVisible(formContinue);
    await tester.tap(formContinue);
    await tester.pumpAndSettle();
    expect(find.text('Profil Bilgileri'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('citizen-profile-continue-button')));
    await tester.pumpAndSettle();

    expect(find.text('Emel YILMAZ'), findsNothing);
    expect(
      find.byKey(const Key('family-information-continue-button')),
      findsOneWidget,
    );

    // Genel kalem aile yönetimini, kişi içindeki buton seçili kişi formunu açar.
    await tester.tap(find.byKey(const Key('family-information-update-button')));
    await tester.pumpAndSettle();
    expect(find.text('Aile Bilgilerini Yönet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('family-editor-back-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('family-information-back-button')));
    await tester.pumpAndSettle();
    expect(find.text('Profil Bilgileri'), findsNWidgets(2));
    expect(find.byKey(const Key('activity-return-dialog')), findsNothing);

    await tester.tap(find.byKey(const Key('citizen-profile-continue-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('family-information-continue-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mülkiyet Durumu'), findsOneWidget);
    expect(find.byKey(const Key('household-continue-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('household-header-back-button')));
    await tester.pumpAndSettle();
    expect(find.text('Başvuru Ekranına Dön'), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-return-stay-button')));
    await tester.pumpAndSettle();

    await answerRequiredHouseholdQuestions(tester);
    await tester.tap(find.byKey(const Key('household-continue-button')));
    await tester.pump();
    expect(find.byKey(const Key('household-camera-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('household-back-button')));
    await tester.pump();
    expect(
      find.byKey(const Key('household-question-MULKIYET_DURUMU')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('activity-return-dialog')), findsNothing);

    await tester.tap(find.byKey(const Key('household-continue-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('household-continue-button')));
    await tester.pumpAndSettle();
    expect(find.text('Tamamla'), findsOneWidget);

    // Tamamla üst oku başvuru formuna atlamadan önceki Hane Durumu
    // adımına dönmeli ve tamamlanmamış başvuru uyarısı göstermemelidir.
    await tester.tap(find.byKey(const Key('completion-header-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('household-camera-button')), findsOneWidget);
    expect(find.byKey(const Key('activity-return-dialog')), findsNothing);

    await tester.tap(find.byKey(const Key('household-continue-button')));
    await tester.pumpAndSettle();
    expect(find.text('Tamamla'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('completion-note-field')),
      'Taslak saha notu',
    );
    await tester.tap(find.byKey(const Key('completion-save-draft-button')));
    await tester.pumpAndSettle();

    expect(find.text('Bekleyen Liste'), findsOneWidget);
    expect(find.text('Tamamlanmış'), findsOneWidget);
    expect(find.text('Tamamla'), findsNothing);
    expect(applicationRepository.createCount, 1);
    expect(applicationRepository.saveFieldDataCount, 1);
    expect(applicationRepository.uploadCount, 0);
    expect(applicationRepository.submitCount, 0);
    expect(
      applicationRepository.lastCreatedDraft?.completionNote,
      'Taslak saha notu',
    );
  });

  testWidgets('kurula gönderilen başvuruyu Bekleyen Listeye taşır', (
    tester,
  ) async {
    final applicationRepository = _FakeApplicationRepository();
    await pumpApp(tester, applicationRepository: applicationRepository);

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Başvuru Yap'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('new-application-tckn-field')),
      '12345678901',
    );
    await tester.enterText(
      find.byKey(const Key('new-application-birth-date-field')),
      '01.01.1990',
    );
    await tester.enterText(
      find.byKey(const Key('new-application-phone-field')),
      '05551234567',
    );

    final helpDropdownControl = find.byKey(
      const Key('new-application-help-dropdown-control'),
    );
    await tester.ensureVisible(helpDropdownControl);
    await tester.tap(helpDropdownControl);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gıda Yardımı').last);
    await tester.pumpAndSettle();

    final formContinue = find.byKey(
      const Key('new-application-continue-button'),
    );
    await tester.ensureVisible(formContinue);
    await tester.tap(formContinue);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('citizen-profile-continue-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('family-information-continue-button')),
    );
    await tester.pumpAndSettle();
    await answerRequiredHouseholdQuestions(tester);
    await tester.tap(find.byKey(const Key('household-continue-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('household-continue-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('completion-note-field')),
      'Gönderilecek kurul notu',
    );
    await tester.tap(find.byKey(const Key('completion-submit-board-button')));
    await tester.pumpAndSettle();

    expect(find.text('Bekleyen Liste'), findsOneWidget);
    expect(find.byKey(const Key('submission-success-notice')), findsOneWidget);
    expect(find.text('Başvuru başarıyla kurula gönderildi.'), findsOneWidget);
    expect(find.text('Tamamlanmış'), findsOneWidget);
    expect(find.text('Tamamla'), findsNothing);
    expect(applicationRepository.createCount, 1);
    expect(applicationRepository.saveFieldDataCount, 1);
    expect(applicationRepository.uploadCount, 0);
    expect(applicationRepository.submitCount, 1);
    expect(applicationRepository.lastSubmittedRowVersion, 'AAAAAAAAAAI=');

    await tester.tap(find.byKey(const Key('home-back-button')));
    await tester.pumpAndSettle();
    expect(find.text('İşlem Seçimi'), findsOneWidget);
    expect(find.text('Mülkiyet Durumu'), findsNothing);
  });
}

class _SuccessfulAuthRepository implements AuthRepository {
  @override
  Future<void> logout() async {}

  @override
  Future<AuthenticationSession?> restoreSession() async => null;

  @override
  Future<AuthenticationSession> login({
    required String email,
    required String password,
    String? municipalityCode,
  }) async {
    return _testSession();
  }
}

class _RestoreAuthRepository extends _SuccessfulAuthRepository {
  _RestoreAuthRepository(this._restore);

  final Future<AuthenticationSession?> Function() _restore;

  @override
  Future<AuthenticationSession?> restoreSession() => _restore();
}

class _EmptyWorkItemsRepository implements WorkItemsRepository {
  @override
  Future<List<WorkItem>> getMyWorkItems({int limit = 100}) async => const [];
}

class _FakeApplicationReferenceRepository
    implements ApplicationReferenceRepository {
  @override
  void clearCache() {}

  @override
  Future<ApplicationReferenceCatalog> getCatalog() async =>
      applicationReferenceTestCatalog;
}

class _FixedWorkItemsRepository implements WorkItemsRepository {
  const _FixedWorkItemsRepository(this.items);

  final List<WorkItem> items;

  @override
  Future<List<WorkItem>> getMyWorkItems({int limit = 100}) async => items;
}

class _SuccessfulKpsProfileRepository implements KpsProfileRepository {
  int lookupCount = 0;
  String? lastIdentityNumber;
  String? lastBirthDate;

  @override
  Future<KpsProfile> getProfile({
    required String identityNumber,
    required String birthDate,
  }) async {
    lookupCount += 1;
    lastIdentityNumber = identityNumber;
    lastBirthDate = birthDate;
    return KpsProfile(
      identityNumber: identityNumber,
      firstName: 'ÖRNEK',
      lastName: 'KİŞİ',
      birthDate: birthDate,
      fullAddress: 'Örnek Mah. Test Sk. No: 1',
      maritalStatus: 'Evli',
    );
  }
}

class _FakeApplicationRepository implements ApplicationRepository {
  _FakeApplicationRepository({this.loadedDraft});

  final LoadedApplicationDraft? loadedDraft;
  int getCount = 0;
  int createCount = 0;
  int saveFieldDataCount = 0;
  int uploadCount = 0;
  int submitCount = 0;
  ApplicationDraft? lastCreatedDraft;
  String? lastSubmittedRowVersion;

  @override
  Future<LoadedApplicationDraft> getDraft({
    required String applicationPublicId,
    required ApplicationReferenceCatalog referenceCatalog,
  }) async {
    getCount += 1;
    final result = loadedDraft;
    if (result == null) {
      throw UnimplementedError('Bu fake testte taslak okuma kullanılmıyor.');
    }
    expect(result.entry.applicationPublicId, applicationPublicId);
    return result;
  }

  @override
  Future<ApplicationLifecycleEntry> createDraft({
    required ApplicationDraft draft,
    required String idempotencyKey,
  }) async {
    createCount += 1;
    lastCreatedDraft = draft;
    expect(idempotencyKey.length, greaterThanOrEqualTo(8));
    return const ApplicationLifecycleEntry(
      applicationPublicId: 'application-public-id',
      applicationNumber: '150',
      statusCode: 'TASLAK',
      isEditable: true,
      rowVersion: 'AAAAAAAAAAE=',
    );
  }

  @override
  Future<ApplicationLifecycleEntry> updateDraft({
    required ApplicationDraft draft,
    required String applicationPublicId,
    required String expectedRowVersion,
  }) async {
    return ApplicationLifecycleEntry(
      applicationPublicId: applicationPublicId,
      applicationNumber: '150',
      statusCode: 'TASLAK',
      isEditable: true,
      rowVersion: expectedRowVersion,
    );
  }

  @override
  Future<ApplicationLifecycleEntry> saveFieldData({
    required ApplicationDraft draft,
    required String applicationPublicId,
    required String expectedRowVersion,
  }) async {
    saveFieldDataCount += 1;
    expect(applicationPublicId, 'application-public-id');
    expect(expectedRowVersion, 'AAAAAAAAAAE=');
    return const ApplicationLifecycleEntry(
      applicationPublicId: 'application-public-id',
      applicationNumber: '150',
      statusCode: 'TASLAK',
      isEditable: true,
      rowVersion: 'AAAAAAAAAAI=',
    );
  }

  @override
  Future<ApplicationLifecycleEntry> uploadPhotos({
    required ApplicationDraft draft,
    required String applicationPublicId,
    required String expectedRowVersion,
    required String idempotencyKey,
  }) async {
    uploadCount += 1;
    expect(applicationPublicId, 'application-public-id');
    expect(expectedRowVersion, 'AAAAAAAAAAI=');
    expect(idempotencyKey.length, greaterThanOrEqualTo(8));
    return const ApplicationLifecycleEntry(
      applicationPublicId: 'application-public-id',
      applicationNumber: '150',
      statusCode: 'TASLAK',
      isEditable: true,
      rowVersion: 'AAAAAAAAAAM=',
    );
  }

  @override
  Future<ApplicationLifecycleEntry> submitToBoard({
    required String applicationPublicId,
    required String expectedRowVersion,
    required String idempotencyKey,
  }) async {
    submitCount += 1;
    lastSubmittedRowVersion = expectedRowVersion;
    expect(applicationPublicId, 'application-public-id');
    expect(idempotencyKey.length, greaterThanOrEqualTo(8));
    return const ApplicationLifecycleEntry(
      applicationPublicId: 'application-public-id',
      applicationNumber: '150',
      statusCode: 'KURUL_BEKLIYOR',
      isEditable: false,
      rowVersion: 'AAAAAAAAAAI=',
    );
  }
}

AuthenticationSession _testSession() => AuthenticationSession(
  tokens: AuthTokens(
    accessToken: 'test-access-token',
    accessTokenExpiresAtUtc: DateTime.utc(2026, 8, 10, 13),
    refreshToken: 'test-refresh-token',
    refreshTokenExpiresAtUtc: DateTime.utc(2026, 8, 17, 12),
  ),
  user: const AuthenticatedUser(
    userId: 'test-user-id',
    email: 'test@belediye.com',
    displayName: 'Test Personeli',
    municipalityCode: 'DEMOLAR',
    municipalityName: 'Demolar Belediyesi',
    municipalityMembershipId: 1,
    roles: ['PERSONNEL'],
  ),
);
