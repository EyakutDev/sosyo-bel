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

  testWidgets('parolayı gösterip yeniden gizler', (tester) async {
    await pumpLogin(tester, onLogin: (_, _) async {});
    final passwordFieldFinder = find.byKey(const Key('login-password-field'));

    await tester.enterText(passwordFieldFinder, 'TestSifresi123!');
    expect(tester.widget<TextField>(passwordFieldFinder).obscureText, isTrue);

    await tester.tap(find.byKey(const Key('login-password-visibility-toggle')));
    await tester.pump();
    expect(tester.widget<TextField>(passwordFieldFinder).obscureText, isFalse);
    expect(find.byTooltip('Parolayı gizle'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-password-visibility-toggle')));
    await tester.pump();
    expect(tester.widget<TextField>(passwordFieldFinder).obscureText, isTrue);
    expect(find.byTooltip('Parolayı göster'), findsOneWidget);
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

    expect(find.text('Kullanıcı adınızı girin.'), findsOneWidget);
    expect(callbackCalled, isFalse);
  });

  testWidgets('geçerli bilgileri gönderirken butonda yüklenme gösterir', (
    tester,
  ) async {
    final completer = Completer<void>();
    String? submittedUsername;
    String? submittedPassword;
    await pumpLogin(
      tester,
      onLogin: (username, password) {
        submittedUsername = username;
        submittedPassword = password;
        return completer.future;
      },
    );

    await tester.enterText(
      find.byKey(const Key('login-username-field')),
      '  personel  ',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'TestSifresi123!',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pump();

    expect(find.byKey(const Key('login-loading-indicator')), findsOneWidget);
    expect(submittedUsername, 'personel');
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
          message: 'Kullanıcı adı veya şifre hatalı.',
          statusCode: 401,
          code: 'invalid_credentials',
        );
      },
    );

    await tester.enterText(
      find.byKey(const Key('login-username-field')),
      'personel',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'yanlis-sifre',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Kullanıcı adı veya şifre hatalı.'), findsOneWidget);
    expect(find.byKey(const Key('login-error-message')), findsOneWidget);
  });
}
