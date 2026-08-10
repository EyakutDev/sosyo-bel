import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/activity/presentation/family_information_editor_page.dart';
import 'package:sosyo_bel/features/activity/presentation/fixtures/family_information_design_fixture.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/widgets/family_member_form_sheet.dart';

void main() {
  test('ortak yakınlık, çalışma, eğitim ve yaşam seçeneklerini sınırlar', () {
    expect(FamilyMemberFormOptions.employmentStatuses, [
      'Çalışıyor',
      'Çalışmıyor',
      'Emekli',
    ]);
    expect(FamilyMemberFormOptions.vitalStatuses, ['Sağ', 'Ölü']);
    expect(
      FamilyMemberFormOptions.educationStatuses,
      containsAll(['Okuryazar Değil', 'Lise', 'Lisans', 'Doktora']),
    );
    expect(
      FamilyMemberFormOptions.relationships,
      contains(FamilyMemberFormOptions.otherRelationship),
    );
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    required ValueChanged<FamilyInformationViewData> onChanged,
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FamilyInformationEditorPage(
          data: FamilyInformationDesignFixture.family,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> selectDropdownOption(
    WidgetTester tester, {
    required Key fieldKey,
    required String option,
  }) async {
    final dropdown = find.byKey(fieldKey);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    final optionFinder = find.text(option);
    var scrollAttempt = 0;
    while (optionFinder.evaluate().isEmpty && scrollAttempt < 5) {
      // Satır içi seçenek listesi kendi içinde kayar; formun ana kaydırıcısını
      // hareket ettirmeden görünmeyen seçeneklere ulaşırız.
      await tester.drag(find.byType(ListView).last, const Offset(0, -220));
      await tester.pumpAndSettle();
      scrollAttempt++;
    }
    expect(optionFinder, findsWidgets);
    await tester.tap(optionFinder.last);
    await tester.pumpAndSettle();
  }

  Future<void> enterNewMember(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('family-member-full-name-field')),
      'Ayşe YILMAZ',
    );
    await selectDropdownOption(
      tester,
      fieldKey: const Key('family-member-relationship-field'),
      option: 'Diğer',
    );
    // Diğer seçildiğinde yeni bir alan açılmaz; aynı yakınlık alanı
    // personelin özel değeri yazabileceği metin alanına dönüşür.
    await tester.enterText(
      find.byKey(const Key('family-member-relationship-field')),
      'Kuzen',
    );
    await tester.enterText(
      find.byKey(const Key('family-member-age-field')),
      '42',
    );
    await tester.enterText(
      find.byKey(const Key('family-member-disability-field')),
      'Yok',
    );
    await selectDropdownOption(
      tester,
      fieldKey: const Key('family-member-employment-field'),
      option: 'Çalışıyor',
    );
    await selectDropdownOption(
      tester,
      fieldKey: const Key('family-member-education-field'),
      option: 'Lise',
    );
    await selectDropdownOption(
      tester,
      fieldKey: const Key('family-member-vital-field'),
      option: 'Sağ',
    );
  }

  testWidgets('manuel yeni yakın ekler ve değişikliği dış akışa bildirir', (
    tester,
  ) async {
    FamilyInformationViewData? changedData;
    await pumpEditor(tester, onChanged: (data) => changedData = data);

    expect(find.text('Aile Bilgilerini Yönet'), findsOneWidget);
    expect(find.text('Yeni Yakın Ekle'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

    await tester.tap(find.byKey(const Key('family-editor-add-member-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('family-member-form-sheet')), findsOneWidget);

    await enterNewMember(tester);
    final saveButton = find.byKey(const Key('family-member-save-button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(changedData?.members, hasLength(6));
    expect(changedData?.members.last.fullName, 'Ayşe YILMAZ');
    expect(changedData?.members.last.relationship, 'Kuzen');
    expect(changedData?.members.last.details?.employmentStatus, 'Çalışıyor');
    expect(changedData?.members.last.details?.educationStatus, 'Lise');
    expect(changedData?.members.last.details?.vitalStatus, 'Sağ');
    await tester.scrollUntilVisible(
      find.text('Ayşe YILMAZ'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ayşe YILMAZ'), findsOneWidget);
    expect(find.text('Yakın bilgisi eklendi.'), findsOneWidget);
  });

  testWidgets(
    'açılan seçenek listesi alanla aynı genişliktedir ve alt alanı aşağı iter',
    (tester) async {
      await pumpEditor(tester, onChanged: (_) {});
      await tester.tap(
        find.byKey(const Key('family-editor-add-member-button')),
      );
      await tester.pumpAndSettle();

      final relationshipField = find.byKey(
        const Key('family-member-relationship-field'),
      );
      final ageField = find.byKey(const Key('family-member-age-field'));
      final ageTopBeforeOpening = tester.getTopLeft(ageField).dy;

      await tester.tap(relationshipField);
      await tester.pumpAndSettle();

      final options = find.byKey(
        const Key('family-member-relationship-options'),
      );
      final fieldRect = tester.getRect(relationshipField);
      final optionsRect = tester.getRect(options);
      final ageRect = tester.getRect(ageField);

      expect(optionsRect.width, fieldRect.width);
      expect(optionsRect.left, fieldRect.left);
      expect(optionsRect.top, greaterThan(fieldRect.bottom));
      expect(ageRect.top, greaterThan(optionsRect.bottom));
      expect(ageRect.top, greaterThan(ageTopBeforeOpening));
    },
  );

  testWidgets('mevcut yakının sınırlı bilgilerini günceller', (tester) async {
    FamilyInformationViewData? changedData;
    await pumpEditor(tester, onChanged: (data) => changedData = data);

    final editButton = find.byKey(const Key('family-editor-edit-member-1'));
    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(find.text('Yakın Bilgisini Güncelle'), findsOneWidget);
    await selectDropdownOption(
      tester,
      fieldKey: const Key('family-member-education-field'),
      option: 'Lise',
    );
    final saveButton = find.byKey(const Key('family-member-save-button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(changedData?.members[1].details?.educationStatus, 'Lise');
    expect(find.text('Lise'), findsOneWidget);
    expect(find.text('Yakın bilgisi güncellendi.'), findsOneWidget);
  });
}
