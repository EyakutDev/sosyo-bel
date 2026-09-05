import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/activity/presentation/application_completion_page.dart';
import 'package:sosyo_bel/features/activity/presentation/fixtures/citizen_profile_design_fixture.dart';
import 'package:sosyo_bel/features/activity/presentation/fixtures/family_information_design_fixture.dart';
import 'package:sosyo_bel/features/activity/presentation/models/application_completion_payload.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

void main() {
  const householdDraft = HouseholdStatusDraft(
    answers: {'MULKIYET_DURUMU': 'EV_SAHIBI'},
    photos: [],
    saveToBeneficiaryDirectory: false,
  );
  const applicationDraft = ApplicationDraft(
    applicationForm: NewApplicationFormData(
      identityNumber: '12345678901',
      birthDate: '03/11/2002',
      disabilityStatusCode: 'YOK',
      disabilityStatus: 'Yok',
      phoneNumber: '(534)-551-2872',
      helpTypeCode: 'GIDA',
      helpType: 'Gıda Yardımı',
      description: 'Başvuru açıklaması',
    ),
    citizenProfile: CitizenProfileDesignFixture.profile,
    familyInformation: FamilyInformationDesignFixture.family,
    householdStatus: householdDraft,
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    VoidCallback? onBack,
    ApplicationCompletionAction? onSaveDraft,
    ApplicationCompletionAction? onSubmitToBoard,
    VoidCallback? onSubmissionConfirmed,
    ValueChanged<String>? onNoteChanged,
    bool initiallySubmitted = false,
    double topSafeArea = 0,
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(375, 812),
            padding: EdgeInsets.only(top: topSafeArea),
          ),
          child: ApplicationCompletionPage(
            applicationDraft: applicationDraft,
            onBack: onBack ?? () {},
            onSaveDraft: onSaveDraft ?? (_) async {},
            onSubmitToBoard: onSubmitToBoard ?? (_) async {},
            onSubmissionConfirmed: onSubmissionConfirmed,
            onNoteChanged: onNoteChanged,
            initiallySubmitted: initiallySubmitted,
          ),
        ),
      ),
    );
  }

  testWidgets('Figma Tamamla içeriğini ve iki işlemi gösterir', (tester) async {
    var backCount = 0;
    await pumpPage(tester, onBack: () => backCount++);

    expect(find.text('Tamamla'), findsOneWidget);
    expect(find.text('Haneye Ait Ekstra Notunuz'), findsOneWidget);
    expect(
      find.text(
        'Girdiğiniz Bilgileri Kontrol Edin\n'
        'Ve İletmek İstediğiniz Not Varsa Paylaşın',
      ),
      findsOneWidget,
    );
    expect(find.text('Taslağı Kaydet'), findsOneWidget);
    expect(find.text('Kurula Gönder'), findsOneWidget);

    await tester.tap(find.byKey(const Key('completion-header-back-button')));
    expect(backCount, 1);
  });

  testWidgets('geri düğmesini cihazın üst güvenli alanının altında tutar', (
    tester,
  ) async {
    var backCount = 0;
    await pumpPage(tester, onBack: () => backCount++, topSafeArea: 44);

    final backButton = find.byKey(const Key('completion-header-back-button'));
    expect(tester.getTopLeft(backButton).dy, greaterThanOrEqualTo(44));
    await tester.tap(backButton);
    expect(backCount, 1);
  });

  testWidgets('taslak notunu ve hane verisini callback ile taşır', (
    tester,
  ) async {
    ApplicationCompletionPayload? savedPayload;
    String? changedNote;
    await pumpPage(
      tester,
      onSaveDraft: (value) async => savedPayload = value,
      onNoteChanged: (value) => changedNote = value,
    );

    await tester.enterText(
      find.byKey(const Key('completion-note-field')),
      'Hane için kurul notu',
    );
    await tester.tap(find.byKey(const Key('completion-save-draft-button')));
    await tester.pump();

    expect(savedPayload?.note, 'Hane için kurul notu');
    expect(changedNote, 'Hane için kurul notu');
    expect(savedPayload?.householdDraft, same(householdDraft));
    expect(
      savedPayload?.applicationDraft.applicationForm?.identityNumber,
      '12345678901',
    );
    expect(
      savedPayload?.applicationDraft.familyInformation,
      same(FamilyInformationDesignFixture.family),
    );
  });

  testWidgets('kurula gönderildikten sonra alanı ve işlemleri kilitler', (
    tester,
  ) async {
    var submitCount = 0;
    var saveCount = 0;
    var confirmationCount = 0;
    await pumpPage(
      tester,
      onSaveDraft: (_) async => saveCount++,
      onSubmitToBoard: (_) async => submitCount++,
      onSubmissionConfirmed: () => confirmationCount++,
    );

    await tester.enterText(
      find.byKey(const Key('completion-note-field')),
      'Gönderilecek not',
    );
    await tester.tap(find.byKey(const Key('completion-submit-board-button')));
    await tester.pumpAndSettle();

    final noteField = tester.widget<TextField>(
      find.byKey(const Key('completion-note-field')),
    );
    final saveButton = tester.widget<InkWell>(
      find.byKey(const Key('completion-save-draft-button')),
    );
    final submitButton = tester.widget<InkWell>(
      find.byKey(const Key('completion-submit-board-button')),
    );

    expect(submitCount, 1);
    expect(noteField.readOnly, isTrue);
    expect(saveButton.onTap, isNull);
    expect(submitButton.onTap, isNull);
    expect(
      find.byKey(const Key('completion-submission-success-dialog')),
      findsOneWidget,
    );
    expect(find.text('Başvuru kurula gönderildi'), findsOneWidget);
    expect(find.text('Görevlere Dön'), findsOneWidget);
    expect(saveCount, 0);
    expect(submitCount, 1);

    await tester.tap(
      find.byKey(const Key('completion-success-return-to-tasks-button')),
    );
    await tester.pumpAndSettle();
    expect(confirmationCount, 1);
  });

  testWidgets(
    'API hatasında mesaj gösterip formu tekrar kullanılabilir yapar',
    (tester) async {
      await pumpPage(
        tester,
        onSubmitToBoard: (_) async {
          throw const ApiException(
            kind: ApiErrorKind.connection,
            message: 'Sunucuya bağlanılamadı.',
          );
        },
      );

      await tester.enterText(
        find.byKey(const Key('completion-note-field')),
        'Korunacak not',
      );
      await tester.tap(find.byKey(const Key('completion-submit-board-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('completion-submission-error-dialog')),
        findsOneWidget,
      );
      expect(find.text('Başvuru gönderilemedi'), findsOneWidget);
      expect(find.text('Sunucuya bağlanılamadı.'), findsOneWidget);
      expect(
        find.text('Bilgileriniz ve fotoğraflarınız korunuyor.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('completion-error-close-button')));
      await tester.pumpAndSettle();

      final noteField = tester.widget<TextField>(
        find.byKey(const Key('completion-note-field')),
      );
      final submitButton = tester.widget<InkWell>(
        find.byKey(const Key('completion-submit-board-button')),
      );
      expect(noteField.controller?.text, 'Korunacak not');
      expect(noteField.readOnly, isFalse);
      expect(submitButton.onTap, isNotNull);
    },
  );

  testWidgets('başarısız kurul gönderimini aynı verilerle tekrar dener', (
    tester,
  ) async {
    var submitCount = 0;
    await pumpPage(
      tester,
      onSubmitToBoard: (_) async {
        submitCount++;
        if (submitCount == 1) {
          throw const ApiException(
            kind: ApiErrorKind.server,
            message: 'Geçici bir sunucu hatası oluştu.',
          );
        }
      },
    );

    await tester.enterText(
      find.byKey(const Key('completion-note-field')),
      'Aynı kalacak not',
    );
    await tester.tap(find.byKey(const Key('completion-submit-board-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('completion-error-retry-button')));
    await tester.pumpAndSettle();

    expect(submitCount, 2);
    expect(
      find.byKey(const Key('completion-submission-success-dialog')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('completion-note-field')))
          .controller
          ?.text,
      'Aynı kalacak not',
    );
  });
}
