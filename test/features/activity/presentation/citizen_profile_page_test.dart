import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/activity/presentation/citizen_profile_page.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    VoidCallback? onBack,
    required VoidCallback onContinue,
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CitizenProfilePage(
          onBack: onBack ?? () {},
          onContinue: onContinue,
        ),
      ),
    );
  }

  testWidgets('Figma profil bilgilerini ve aktivite adımlarını gösterir', (
    tester,
  ) async {
    await pumpPage(tester, onContinue: () {});

    expect(find.text('Aktivite'), findsOneWidget);
    expect(find.text('Profil Bilgileri'), findsNWidgets(2));
    expect(find.text('Aile Bilgileri'), findsOneWidget);
    expect(find.text('Hane Durumu'), findsOneWidget);
    expect(find.text('Ahmet YILMAZ'), findsOneWidget);
    expect(find.text('#148'), findsOneWidget);
  });

  testWidgets('Geri butonu callback fonksiyonunu çalıştırır', (tester) async {
    var backCount = 0;
    await pumpPage(tester, onBack: () => backCount++, onContinue: () {});

    final backButton = find.byKey(const Key('citizen-profile-back-button'));
    final hitArea = tester.getRect(backButton);

    expect(hitArea.size, const Size(48, 48));

    // Görsel okun dışında kalan şeffaf kenar da gerçek cihazda dokunmayı
    // yakalamalıdır; yalnızca SVG'nin küçük yüzeyine bağımlı kalmıyoruz.
    await tester.tapAt(hitArea.topLeft + const Offset(3, 3));

    expect(backCount, 1);
  });

  testWidgets('Devam Et callback fonksiyonunu çalıştırır', (tester) async {
    var continueCount = 0;
    await pumpPage(tester, onContinue: () => continueCount++);

    await tester.tap(find.byKey(const Key('citizen-profile-continue-button')));
    await tester.pump();

    expect(continueCount, 1);
  });
}
