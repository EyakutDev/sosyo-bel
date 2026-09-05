import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/constants/app_assets.dart';
import 'package:sosyo_bel/features/splash/presentation/splash_page.dart';

void main() {
  testWidgets('logo ve uygulama adını yatay ve dengeli gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    final row = tester.widget<Row>(
      find.ancestor(
        of: find.byKey(const Key('splash-logo')),
        matching: find.byType(Row),
      ),
    );
    final logo = tester.widget<Image>(find.byKey(const Key('splash-logo')));
    final title = tester.widget<Text>(find.byKey(const Key('splash-title')));

    expect(find.byKey(const Key('splash-page')), findsOneWidget);
    expect(row.mainAxisSize, MainAxisSize.min);
    expect((logo.image as AssetImage).assetName, AppAssets.splashLogo);
    expect(logo.width, 64);
    expect(logo.height, 64);
    expect(title.data, 'Sosyo-Bel');
    expect(title.style?.fontSize, 24);
  });
}
