import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/constants/app_assets.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/activity/presentation/household_status_page.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';

void main() {
  const designPhoto = HouseholdPhotoViewData.asset(
    AppAssets.householdDesignHouse,
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    VoidCallback? onBack,
    VoidCallback? onHeaderBack,
    ValueChanged<HouseholdStatusDraft>? onContinue,
    HouseholdPhotoCapture? onCapturePhoto,
    HouseholdStatusStage initialStage = HouseholdStatusStage.questions,
    List<HouseholdPhotoViewData> initialPhotos = const [],
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HouseholdStatusPage(
          initialStage: initialStage,
          initialPhotos: initialPhotos,
          onBack: onBack ?? () {},
          onHeaderBack: onHeaderBack,
          onContinue: onContinue ?? (_) {},
          onCapturePhoto: onCapturePhoto ?? () async => null,
        ),
      ),
    );
  }

  testWidgets('Figma hane adımlarını ve beş saha sorusunu gösterir', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Aktivite'), findsOneWidget);
    expect(find.text('Profil Bilgileri'), findsOneWidget);
    expect(find.text('Aile Bilgileri'), findsOneWidget);
    expect(find.text('Hane Durumu'), findsOneWidget);
    expect(find.text('Sorular'), findsOneWidget);
    expect(find.text('Fotoğraflar'), findsOneWidget);
    expect(find.text('Mülkiyet Durumu'), findsOneWidget);
    expect(find.text('Mülkün Tipi ?'), findsOneWidget);
    expect(find.text('Ev Temiz mi?'), findsOneWidget);
    expect(find.text('Barındığın Yeri Durumu?'), findsOneWidget);
    expect(find.text('Evdeki Eşyalar'), findsOneWidget);
  });

  testWidgets('alt geri aşama sırasını, üst geri ayrı callbacki çalıştırır', (
    tester,
  ) async {
    var externalBackCount = 0;
    var headerBackCount = 0;
    await pumpPage(
      tester,
      onBack: () => externalBackCount++,
      onHeaderBack: () => headerBackCount++,
    );

    await tester.tap(find.byKey(const Key('household-continue-button')));
    await tester.pump();
    expect(find.byKey(const Key('household-camera-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('household-back-button')));
    await tester.pump();
    expect(externalBackCount, 0);
    expect(find.text('Mülkiyet Durumu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('household-back-button')));
    expect(externalBackCount, 1);

    await tester.tap(find.byKey(const Key('household-header-back-button')));
    expect(headerBackCount, 1);
    expect(externalBackCount, 1);
  });

  testWidgets('cevap, fotoğraf ve dizin tercihini taslakta korur', (
    tester,
  ) async {
    HouseholdStatusDraft? submittedDraft;
    await pumpPage(
      tester,
      onContinue: (draft) => submittedDraft = draft,
      onCapturePhoto: () async => designPhoto,
    );

    await tester.tap(
      find.byKey(const Key('household-question-ownership-status')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ev Sahibi').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('household-continue-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('household-camera-button')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('household-save-directory-checkbox')),
    );
    await tester.tap(find.byKey(const Key('household-continue-button')));
    await tester.pump();

    expect(submittedDraft?.answers['ownership-status'], 'Ev Sahibi');
    expect(submittedDraft?.photos, hasLength(1));
    expect(submittedDraft?.saveToBeneficiaryDirectory, isTrue);
  });

  testWidgets('on beşinci fotoğrafı ekler ve on altıncıyı engeller', (
    tester,
  ) async {
    var captureCount = 0;
    HouseholdStatusDraft? submittedDraft;
    await pumpPage(
      tester,
      initialStage: HouseholdStatusStage.photos,
      initialPhotos: List.filled(14, designPhoto),
      onCapturePhoto: () async {
        captureCount++;
        return designPhoto;
      },
      onContinue: (draft) => submittedDraft = draft,
    );

    await tester.tap(find.byKey(const Key('household-camera-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('household-camera-button')));
    await tester.pump();

    expect(captureCount, 1);
    expect(find.text(HouseholdPhotoPolicy.maxPhotoMessage), findsOneWidget);

    await tester.tap(find.byKey(const Key('household-continue-button')));
    expect(submittedDraft?.photos, hasLength(15));
  });

  testWidgets('fotoğrafı siler ve boşalan on beşinci yere yeniden ekler', (
    tester,
  ) async {
    var captureCount = 0;
    HouseholdStatusDraft? submittedDraft;
    await pumpPage(
      tester,
      initialStage: HouseholdStatusStage.photos,
      initialPhotos: List.filled(15, designPhoto),
      onCapturePhoto: () async {
        captureCount++;
        return designPhoto;
      },
      onContinue: (draft) => submittedDraft = draft,
    );

    expect(find.byKey(const Key('household-photo-remove-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('household-photo-remove-0')));
    await tester.pump();

    // Silme sonrası sınır yeniden hesaplanır ve kamera bir fotoğraf daha kabul eder.
    await tester.tap(find.byKey(const Key('household-camera-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('household-continue-button')));

    expect(captureCount, 1);
    expect(submittedDraft?.photos, hasLength(15));
  });
}
