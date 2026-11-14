import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';
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
    required Future<void> Function(NewApplicationFormData) onContinue,
    NewApplicationFormData? initialData,
    bool isEditingSubmittedApplication = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NewApplicationPage(
          referenceCatalog: _referenceCatalog,
          initialData: initialData,
          isEditingSubmittedApplication: isEditingSubmittedApplication,
          onContinue: onContinue,
        ),
      ),
    );
  }

  testWidgets('paylaşılan form alanlarını gösterir', (tester) async {
    await pumpPage(tester, onContinue: (_) async {});

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
    expect(
      find.byKey(const Key('new-application-next-field-button')),
      findsOneWidget,
    );
  });

  testWidgets('sağdaki ok sıradaki yazı alanına geçirir', (tester) async {
    await pumpPage(tester, onContinue: (_) async {});

    EditableText editableField(String key) {
      return tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(EditableText),
        ),
      );
    }

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('new-application-tckn-field')),
        matching: find.byType(EditableText),
      ),
    );
    await tester.pump();
    expect(
      editableField('new-application-tckn-field').focusNode.hasFocus,
      isTrue,
    );

    await tester.tap(
      find.byKey(const Key('new-application-next-field-button')),
    );
    await tester.pumpAndSettle();

    expect(
      editableField('new-application-birth-date-field').focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('TCKN alanı yalnızca en fazla 11 rakam kabul eder', (
    tester,
  ) async {
    await pumpPage(tester, onContinue: (_) async {});

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
    await pumpPage(tester, onContinue: (_) async {});

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
      await pumpPage(tester, onContinue: (_) async {});

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
      onContinue: (data) async {
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
    expect(submittedData?.disabilityStatusCode, 'YOK');
    expect(submittedData?.disabilityStatus, 'Yok');
    expect(submittedData?.phoneNumber, '(555)-123-4567');
    expect(submittedData?.helpTypeCode, 'GIDA');
    expect(submittedData?.helpType, 'Gıda Yardımı');
    expect(submittedData?.description, 'Gıda desteği talebi');
  });

  testWidgets('mevcut başvuru taslağındaki form verisini geri yükler', (
    tester,
  ) async {
    const initialData = NewApplicationFormData(
      identityNumber: '12345678901',
      birthDate: '03/11/2002',
      disabilityStatusCode: 'ORTOPEDIK',
      disabilityStatus: 'Ortopedik',
      phoneNumber: '(534)-551-2872',
      helpTypeCode: 'NAKDI',
      helpType: 'Nakdi Yardım',
      description: 'Korunan açıklama',
    );
    await pumpPage(tester, initialData: initialData, onContinue: (_) async {});

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

  testWidgets('KPS sorgusu sürerken butonu kilitler ve yükleme gösterir', (
    tester,
  ) async {
    final completer = Completer<void>();
    var callCount = 0;
    await pumpPage(
      tester,
      onContinue: (_) {
        callCount += 1;
        return completer.future;
      },
    );
    await _enterRequiredFormData(tester);

    final button = find.byKey(const Key('new-application-continue-button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(callCount, 1);
    expect(
      find.byKey(const Key('new-application-kps-loading-indicator')),
      findsOneWidget,
    );
    await tester.tap(button);
    await tester.pump();
    expect(callCount, 1);

    completer.complete();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('new-application-kps-loading-indicator')),
      findsNothing,
    );
  });

  testWidgets('KPS hatasında formu koruyup temalı uyarı gösterir', (
    tester,
  ) async {
    await pumpPage(
      tester,
      onContinue: (_) => throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'KPS sorgulama yetkisi bulunmuyor.',
      ),
    );
    await _enterRequiredFormData(tester);

    final button = find.byKey(const Key('new-application-continue-button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('new-application-kps-error-notice')),
      findsOneWidget,
    );
    expect(find.text('KPS sorgulama yetkisi bulunmuyor.'), findsOneWidget);
    expect(find.text('Yeni Başvuru'), findsOneWidget);
    expect(find.text('12345678901'), findsOneWidget);
  });

  testWidgets('duzenleme modunda KPS kimlik alanlarini kilitler', (
    tester,
  ) async {
    const initialData = NewApplicationFormData(
      identityNumber: '12345678901',
      birthDate: '03/11/2002',
      disabilityStatusCode: 'YOK',
      disabilityStatus: 'Yok',
      phoneNumber: '(534)-551-2872',
      helpTypeCode: 'GIDA',
      helpType: 'Gıda Yardımı',
      description: 'Mevcut açıklama',
    );
    await pumpPage(
      tester,
      initialData: initialData,
      isEditingSubmittedApplication: true,
      onContinue: (_) async {},
    );

    EditableText field(String key) {
      return tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(EditableText),
        ),
      );
    }

    expect(find.text('Başvuruyu Düzenle'), findsOneWidget);
    expect(field('new-application-tckn-field').readOnly, isTrue);
    expect(field('new-application-birth-date-field').readOnly, isTrue);
    expect(field('new-application-phone-field').readOnly, isFalse);
    expect(field('new-application-description-field').readOnly, isFalse);
  });
}

Future<void> _enterRequiredFormData(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('new-application-tckn-field')),
    '12345678901',
  );
  await tester.enterText(
    find.byKey(const Key('new-application-birth-date-field')),
    '14.09.1986',
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
}

const _referenceCatalog = ApplicationReferenceCatalog(
  helpTypes: [
    ApplicationReferenceOption(code: 'GIDA', label: 'Gıda Yardımı'),
    ApplicationReferenceOption(code: 'NAKDI', label: 'Nakdi Yardım'),
  ],
  disabilityStatuses: [
    ApplicationReferenceOption(code: 'YOK', label: 'Yok'),
    ApplicationReferenceOption(code: 'ORTOPEDIK', label: 'Ortopedik'),
  ],
  relationships: [],
  employmentStatuses: [],
  educationStatuses: [],
  vitalStatuses: [],
  householdQuestions: [],
);
