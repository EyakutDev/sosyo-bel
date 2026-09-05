import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/features/action_selection/presentation/action_selection_page.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required VoidCallback onNewApplication,
    required VoidCallback onTasks,
    Future<void> Function()? onLogout,
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ActionSelectionPage(
          onNewApplication: onNewApplication,
          onTasks: onTasks,
          onLogout: onLogout ?? () async {},
        ),
      ),
    );
  }

  testWidgets('başvuru ve görev seçeneklerini gösterir', (tester) async {
    await pumpPage(tester, onNewApplication: () {}, onTasks: () {});

    expect(find.text('Başvuru Yap'), findsOneWidget);
    expect(find.text('Görevler'), findsOneWidget);
    expect(
      find.text('Yeni sosyal yardım başvurusu oluşturun.'),
      findsOneWidget,
    );
    expect(find.text('Görevlerinizi görüntüleyin ve yönetin.'), findsOneWidget);
    expect(
      find.byKey(const Key('action-selection-brand-logo')),
      findsOneWidget,
    );
    expect(find.text('Yapmak istediğiniz işlemi seçiniz'), findsOneWidget);
    expect(
      find.byKey(const Key('action-selection-logout-button')),
      findsOneWidget,
    );

    final logoutButton = find.byKey(
      const Key('action-selection-logout-button'),
    );
    expect(tester.getSize(logoutButton), const Size(150, 44));
    expect(tester.getCenter(logoutButton).dx, closeTo(187.5, 0.01));
  });

  testWidgets('seçilen işlemin callback fonksiyonunu çalıştırır', (
    tester,
  ) async {
    var newApplicationTapCount = 0;
    var tasksTapCount = 0;

    await pumpPage(
      tester,
      onNewApplication: () => newApplicationTapCount++,
      onTasks: () => tasksTapCount++,
    );

    await tester.tap(find.text('Başvuru Yap'));
    await tester.pump();
    await tester.tap(find.text('Görevler'));
    await tester.pump();

    expect(newApplicationTapCount, 1);
    expect(tasksTapCount, 1);
  });
  testWidgets('çıkış işlemini onaydan sonra çalıştırır', (tester) async {
    var logoutTapCount = 0;

    await pumpPage(
      tester,
      onNewApplication: () {},
      onTasks: () {},
      onLogout: () async => logoutTapCount++,
    );

    await tester.tap(find.byKey(const Key('action-selection-logout-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logout-confirmation-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout-cancel-button')));
    await tester.pumpAndSettle();
    expect(logoutTapCount, 0);

    await tester.tap(find.byKey(const Key('action-selection-logout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout-confirm-button')));
    await tester.pumpAndSettle();

    expect(logoutTapCount, 1);
  });
}
