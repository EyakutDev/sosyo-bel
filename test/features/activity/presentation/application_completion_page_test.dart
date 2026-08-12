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
    ValueChanged<String>? onNoteChanged,
    bool initiallySubmitted = false,
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ApplicationCompletionPage(
          applicationDraft: applicationDraft,
          onBack: onBack ?? () {},
          onSaveDraft: onSaveDraft ?? (_) async {},
          onSubmitToBoard: onSubmitToBoard ?? (_) async {},
          onNoteChanged: onNoteChanged,
          initiallySubmitted: initiallySubmitted,
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
    await pumpPage(
      tester,
      onSaveDraft: (_) async => saveCount++,
      onSubmitToBoard: (_) async => submitCount++,
    );

    await tester.enterText(
      find.byKey(const Key('completion-note-field')),
      'Gönderilecek not',
    );
    await tester.tap(find.byKey(const Key('completion-submit-board-button')));
    await tester.pump();

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

    await tester.tap(find.byKey(const Key('completion-save-draft-button')));
    await tester.tap(find.byKey(const Key('completion-submit-board-button')));
    expect(saveCount, 0);
    expect(submitCount, 1);
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

      await tester.tap(find.byKey(const Key('completion-submit-board-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('completion-action-error-notice')),
        findsOneWidget,
      );
      expect(find.text('Sunucuya bağlanılamadı.'), findsOneWidget);
      final noteField = tester.widget<TextField>(
        find.byKey(const Key('completion-note-field')),
      );
      final submitButton = tester.widget<InkWell>(
        find.byKey(const Key('completion-submit-board-button')),
      );
      expect(noteField.readOnly, isFalse);
      expect(submitButton.onTap, isNotNull);
    },
  );
}
