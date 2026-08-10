import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/features/auth/presentation/login_page.dart';

void main() {
  Future<void> pumpLogin(
    WidgetTester tester, {
    required LoginCallback onLogin,
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: LoginPage(onLogin: onLogin)));
  }

  testWidgets('giriş ekranının temel öğelerini gösterir', (tester) async {
    await pumpLogin(tester, onLogin: (_, _) async {});

    expect(find.text('Giriş'), findsNWidgets(2));
    expect(find.text('Sosyo-Bel'), findsOneWidget);
    expect(find.text('Saha Ekipleri Modülü'), findsOneWidget);
    expect(find.text('Cats Yazılım San. Tic. Ltd. Şti.'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('boş formu API callbackine göndermeden doğrular', (tester) async {
    var callbackCalled = false;
    await pumpLogin(
      tester,
      onLogin: (_, _) async {
        callbackCalled = true;
      },
    );

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pump();

    expect(find.text('E-posta adresinizi girin.'), findsOneWidget);
    expect(callbackCalled, isFalse);
  });

  testWidgets('geçerli bilgileri gönderirken butonda yüklenme gösterir', (
    tester,
  ) async {
    final completer = Completer<void>();
    String? submittedEmail;
    String? submittedPassword;
    await pumpLogin(
      tester,
      onLogin: (email, password) {
        submittedEmail = email;
        submittedPassword = password;
        return completer.future;
      },
    );

    await tester.enterText(
      find.byKey(const Key('login-email-field')),
      '  test@belediye.com  ',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'TestSifresi123!',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pump();

    expect(find.byKey(const Key('login-loading-indicator')), findsOneWidget);
    expect(submittedEmail, 'test@belediye.com');
    expect(submittedPassword, 'TestSifresi123!');

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-loading-indicator')), findsNothing);
  });

  testWidgets('API hatasını tasarım içindeki hata alanında gösterir', (
    tester,
  ) async {
    await pumpLogin(
      tester,
      onLogin: (_, _) async {
        throw const ApiException(
          kind: ApiErrorKind.unauthenticated,
          message: 'E-posta veya şifre hatalı.',
          statusCode: 401,
          code: 'invalid_credentials',
        );
      },
    );

    await tester.enterText(
      find.byKey(const Key('login-email-field')),
      'test@belediye.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'yanlis-sifre',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
    expect(find.byKey(const Key('login-error-message')), findsOneWidget);
  });
}
