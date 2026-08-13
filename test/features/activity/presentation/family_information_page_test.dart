import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/activity/presentation/family_information_page.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';
import '../../../support/application_reference_test_catalog.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required VoidCallback onBack,
    VoidCallback? onHeaderBack,
    required VoidCallback onContinue,
    required VoidCallback onUpdateInformation,
    required ValueChanged<FamilyMemberViewData> onEditMember,
    ValueChanged<FamilyInformationViewData>? onFamilyChanged,
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
          child: FamilyInformationPage(
            referenceCatalog: applicationReferenceTestCatalog,
            onBack: onBack,
            onHeaderBack: onHeaderBack,
            onContinue: onContinue,
            onUpdateInformation: onUpdateInformation,
            onEditMember: onEditMember,
            onFamilyChanged: onFamilyChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('Figma aile listesini ve aktivite adımlarını gösterir', (
    tester,
  ) async {
    await pumpPage(
      tester,
      onBack: () {},
      onContinue: () {},
      onUpdateInformation: () {},
      onEditMember: (_) {},
    );

    expect(find.text('Aktivite'), findsOneWidget);
    expect(find.text('Profil Bilgileri'), findsOneWidget);
    expect(find.text('Aile Bilgileri'), findsOneWidget);
    expect(find.text('Hane Durumu'), findsOneWidget);
    expect(find.text('Ad Soyad'), findsOneWidget);
    expect(find.text('Yakınlık'), findsOneWidget);
    expect(find.text('Yaş'), findsOneWidget);
    expect(find.text('Ahmet YILMAZ'), findsOneWidget);
    expect(find.text('Emel YILMAZ'), findsOneWidget);
    expect(find.text('Sercan YILMAZ'), findsOneWidget);
    expect(find.text('Sevinc YILMAZ'), findsOneWidget);
    expect(find.text('Mehmet YILMAZ'), findsOneWidget);
  });

  testWidgets('Figma ayrıntısı bulunan aile üyesini açıp kapatır', (
    tester,
  ) async {
    await pumpPage(
      tester,
      onBack: () {},
      onContinue: () {},
      onUpdateInformation: () {},
      onEditMember: (_) {},
    );

    await tester.tap(find.byKey(const Key('family-member-toggle-1')));
    await tester.pump();

    expect(find.text('Engel Durumu'), findsOneWidget);
    expect(find.text('Çalışma Durumu'), findsOneWidget);
    expect(find.text('Eğitim Durumu'), findsOneWidget);
    expect(find.text('Ölü / Sağ'), findsOneWidget);
    expect(find.text('İlk Öğretim Terk'), findsOneWidget);
    expect(find.byKey(const Key('family-member-edit-button')), findsOneWidget);
    expect(
      find.byKey(const Key('family-information-update-button')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('family-member-toggle-1')));
    await tester.pump();

    expect(find.text('Engel Durumu'), findsNothing);
    expect(
      find.byKey(const Key('family-information-update-button')),
      findsOneWidget,
    );
  });

  testWidgets('geri callbacklerini ayırır ve seçilen kişiyi günceller', (
    tester,
  ) async {
    var backCount = 0;
    var headerBackCount = 0;
    var continueCount = 0;
    var updateCount = 0;
    FamilyMemberViewData? editedMember;
    FamilyInformationViewData? changedFamily;

    await pumpPage(
      tester,
      onBack: () => backCount++,
      onHeaderBack: () => headerBackCount++,
      onContinue: () => continueCount++,
      onUpdateInformation: () => updateCount++,
      onEditMember: (member) => editedMember = member,
      onFamilyChanged: (data) => changedFamily = data,
      topSafeArea: 44,
    );

    await tester.tap(find.byKey(const Key('family-information-update-button')));
    await tester.pumpAndSettle();
    expect(find.text('Aile Bilgilerini Yönet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('family-editor-back-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('family-information-back-button')));
    final headerBackButton = find.byKey(
      const Key('family-information-header-back-button'),
    );
    expect(tester.getTopLeft(headerBackButton).dy, greaterThanOrEqualTo(44));

    await tester.tap(
      find.byKey(const Key('family-information-header-back-button')),
    );
    await tester.tap(
      find.byKey(const Key('family-information-continue-button')),
    );
    await tester.pump();

    expect(updateCount, 0);
    expect(backCount, 1);
    expect(headerBackCount, 1);
    expect(continueCount, 1);

    await tester.tap(find.byKey(const Key('family-member-toggle-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('family-member-edit-button')));
    await tester.pumpAndSettle();
    expect(find.text('Yakın Bilgisini Güncelle'), findsOneWidget);

    final employmentDropdown = find.byKey(
      const Key('family-member-employment-field'),
    );
    await tester.ensureVisible(employmentDropdown);
    await tester.tap(employmentDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çalışıyor').last);
    await tester.pumpAndSettle();
    final saveButton = find.byKey(const Key('family-member-save-button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(editedMember?.fullName, 'Emel YILMAZ');
    expect(editedMember?.details?.employmentStatus, 'Çalışıyor');
    expect(changedFamily?.members[1].details?.employmentStatus, 'Çalışıyor');
    expect(find.text('Çalışıyor'), findsOneWidget);
  });
}
