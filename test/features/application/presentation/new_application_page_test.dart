import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/application/presentation/formatters/day_month_year_input_formatter.dart';
import 'package:sosyo_bel/features/application/presentation/formatters/phone_number_input_formatter.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';
import 'package:sosyo_bel/features/application/presentation/new_application_page.dart';

void main() {
  test('doğum tarihi rakamlarını yazım sırasında GG/AA/YYYY biçimler', () {
    const formatter = DayMonthYearInputFormatter();

    final day = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '03'),
    );
    final fullDate = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '03112002'),
    );

    expect(day.text, '03/');
    expect(fullDate.text, '03/11/2002');
  });

  test('telefon rakamlarını yazım sırasında (5XX)-XXX-XXXX biçimler', () {
    const formatter = PhoneNumberInputFormatter();

    final operator = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '534'),
    );
    final fullNumber = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '5345512872'),
    );
    final numberWithLeadingZero = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '05345512872'),
    );

    expect(operator.text, '(534)-');
    expect(fullNumber.text, '(534)-551-2872');
    expect(numberWithLeadingZero.text, '(534)-551-2872');
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required ValueChanged<NewApplicationFormData> onContinue,
    NewApplicationFormData? initialData,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NewApplicationPage(
          initialData: initialData,
          onContinue: onContinue,
        ),
      ),
    );
  }

  testWidgets('paylaşılan form alanlarını gösterir', (tester) async {
    await pumpPage(tester, onContinue: (_) {});

    expect(find.text('Yeni Başvuru'), findsOneWidget);
    expect(find.text('Kişi Bilgileri'), findsOneWidget);
    expect(find.text('Talep Bilgileri'), findsOneWidget);
    expect(find.text('11 haneli T.C. kimlik numarası'), findsOneWidget);
    expect(find.text('GG/AA/YYYY'), findsOneWidget);
    expect(find.text('+90 (5XX)-XXX-XXXX'), findsOneWidget);
    expect(
      find.text('Talebinizi ve gerekçelerinizi buraya yazabilirsiniz...'),
      findsOneWidget,
    );
  });

  testWidgets('TCKN alanı yalnızca en fazla 11 rakam kabul eder', (
    tester,
  ) async {
    await pumpPage(tester, onContinue: (_) {});

    await tester.enterText(
      find.byKey(const Key('new-application-tckn-field')),
      '12a34567890123',
    );

    final input = tester.widget<TextFormField>(
      find.descendant(
        of: find.byKey(const Key('new-application-tckn-field')),
        matching: find.byType(TextFormField),
      ),
    );
    expect(input.controller?.text, '12345678901');
  });

  testWidgets('telefon alanını yazarken otomatik biçimlendirir', (
    tester,
  ) async {
    await pumpPage(tester, onContinue: (_) {});

    await tester.enterText(
      find.byKey(const Key('new-application-phone-field')),
      '5345512872',
    );

    final input = tester.widget<TextFormField>(
      find.descendant(
        of: find.byKey(const Key('new-application-phone-field')),
        matching: find.byType(TextFormField),
      ),
    );
    expect(input.controller?.text, '(534)-551-2872');
  });

  testWidgets(
    'yardım türü listesi alanla aynı genişlikte açılır ve açıklamayı aşağı iter',
    (tester) async {
      await pumpPage(tester, onContinue: (_) {});

      final control = find.byKey(
        const Key('new-application-help-dropdown-control'),
      );
      final description = find.byKey(
        const Key('new-application-description-field'),
      );
      await tester.ensureVisible(control);
      final descriptionTopBeforeOpening = tester.getTopLeft(description).dy;

      await tester.tap(control);
      await tester.pumpAndSettle();

      final options = find.byKey(
        const Key('new-application-help-dropdown-options'),
      );
      final controlRect = tester.getRect(control);
      final optionsRect = tester.getRect(options);
      final descriptionRect = tester.getRect(description);

      expect(optionsRect.width, controlRect.width);
      expect(optionsRect.left, controlRect.left);
      expect(optionsRect.top, greaterThan(controlRect.bottom));
      expect(descriptionRect.top, greaterThan(optionsRect.bottom));
      expect(descriptionRect.top, greaterThan(descriptionTopBeforeOpening));
    },
  );

  testWidgets('geçerli zorunlu alanlardan sonra onContinue çağırır', (
    tester,
  ) async {
    var continueCount = 0;
    NewApplicationFormData? submittedData;
    await pumpPage(
      tester,
      onContinue: (data) {
        continueCount++;
        submittedData = data;
      },
    );

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
    await tester.enterText(
      find.byKey(const Key('new-application-description-field')),
      'Gıda desteği talebi',
    );

    final helpDropdownControl = find.byKey(
      const Key('new-application-help-dropdown-control'),
    );
    await tester.ensureVisible(helpDropdownControl);
    await tester.tap(helpDropdownControl);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gıda Yardımı').last);
    await tester.pumpAndSettle();

    final continueButton = find.byKey(
      const Key('new-application-continue-button'),
    );
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pump();

    expect(continueCount, 1);
    expect(submittedData?.identityNumber, '12345678901');
    expect(submittedData?.birthDate, '01/01/1990');
    expect(submittedData?.disabilityStatus, 'Yok');
    expect(submittedData?.phoneNumber, '(555)-123-4567');
    expect(submittedData?.helpType, 'Gıda Yardımı');
    expect(submittedData?.description, 'Gıda desteği talebi');
  });

  testWidgets('mevcut başvuru taslağındaki form verisini geri yükler', (
    tester,
  ) async {
    const initialData = NewApplicationFormData(
      identityNumber: '12345678901',
      birthDate: '03/11/2002',
      disabilityStatus: 'Ortopedik',
      phoneNumber: '(534)-551-2872',
      helpType: 'Nakdi Yardım',
      description: 'Korunan açıklama',
    );
    await pumpPage(tester, initialData: initialData, onContinue: (_) {});

    String fieldText(String key) {
      final field = tester.widget<TextFormField>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(TextFormField),
        ),
      );
      return field.controller!.text;
    }

    expect(fieldText('new-application-tckn-field'), initialData.identityNumber);
    expect(
      fieldText('new-application-birth-date-field'),
      initialData.birthDate,
    );
    expect(fieldText('new-application-phone-field'), initialData.phoneNumber);
    expect(
      fieldText('new-application-description-field'),
      initialData.description,
    );
    expect(find.text(initialData.disabilityStatus), findsOneWidget);
    expect(find.text(initialData.helpType), findsOneWidget);
  });
}
