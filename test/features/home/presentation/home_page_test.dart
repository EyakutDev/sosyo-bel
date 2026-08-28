import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/branding/municipality_branding.dart';
import 'package:sosyo_bel/core/constants/app_assets.dart';
import 'package:sosyo_bel/features/home/domain/work_item.dart';
import 'package:sosyo_bel/features/home/domain/work_items_repository.dart';
import 'package:sosyo_bel/features/home/presentation/home_page.dart';

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    MunicipalityBranding branding = MunicipalityBranding.demo,
    WorkItemsRepository? repository,
    Future<void> Function(WorkItem item)? onOpenEditableDraft,
  }) async {
    tester.view.physicalSize = const Size(375, 864);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          municipalityBranding: branding,
          workItemsRepository:
              repository ?? _FakeWorkItemsRepository(() async => _workItems),
          onOpenEditableDraft: onOpenEditableDraft,
        ),
      ),
    );
  }

  testWidgets('API işlerini bekleyen ve tamamlanmış sekmelerine ayırır', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('Hoşgeldiniz'), findsOneWidget);
    expect(find.text('B-2026-150'), findsOneWidget);
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    expect(find.text('Bahçelievler Mahallesi No: 4'), findsOneWidget);
    expect(find.text('Kurulda'), findsOneWidget);
    expect(find.text('B-2026-151'), findsNothing);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Tamamlanmış'));
    await tester.pump();

    expect(find.text('B-2026-150'), findsNothing);
    expect(find.text('B-2026-151'), findsOneWidget);
    expect(find.text('Emel Seçen'), findsOneWidget);
    expect(find.text('Tamamlandı'), findsOneWidget);
  });

  testWidgets('görev yüklenirken mevcut temada ilerleme göstergesi gösterir', (
    tester,
  ) async {
    final completer = Completer<List<WorkItem>>();
    await pumpHome(
      tester,
      repository: _FakeWorkItemsRepository(() => completer.future),
    );
    await tester.pump();

    expect(find.byKey(const Key('home-loading-indicator')), findsOneWidget);

    completer.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('Bekleyen iş bulunmuyor'), findsOneWidget);
  });

  testWidgets('yükleme hatasında tekrar deneyip boş duruma geçer', (
    tester,
  ) async {
    var callCount = 0;
    final repository = _FakeWorkItemsRepository(() async {
      callCount += 1;
      if (callCount == 1) throw Exception('connection');
      return const [];
    });
    await pumpHome(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-error-state')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-retry-button')));
    await tester.pumpAndSettle();

    expect(callCount, 2);
    expect(find.byKey(const Key('home-empty-state')), findsOneWidget);
    expect(find.text('Bekleyen iş bulunmuyor'), findsOneWidget);
  });

  testWidgets('belediyeye özel yerel logoyu aynı alanda gösterir', (
    tester,
  ) async {
    const branding = MunicipalityBranding(
      id: 'cats-municipality',
      displayName: 'Cats Belediyesi',
      localLogoAssetPath: AppAssets.logo,
    );
    await pumpHome(tester, branding: branding);
    await tester.pumpAndSettle();

    final logo = find.byKey(const Key('home-municipality-logo'));
    final image = tester.widget<Image>(
      find.descendant(of: logo, matching: find.byType(Image)),
    );

    expect((image.image as AssetImage).assetName, AppAssets.logo);
    expect(find.bySemanticsLabel('Cats Belediyesi logosu'), findsOneWidget);
  });

  testWidgets('yalnız düzenlenebilir taslak kartını açma callbackine iletir', (
    tester,
  ) async {
    WorkItem? openedItem;
    final editableDraft = WorkItem(
      applicationPublicId: 'draft-1',
      applicationNumber: 'B-2026-152',
      sourceCode: 'OWN_APPLICATION',
      statusCode: 'TASLAK',
      isCompleted: false,
      isEditable: true,
      activityAtUtc: DateTime.utc(2026, 8, 11, 10),
    );
    await pumpHome(
      tester,
      repository: _FakeWorkItemsRepository(() async => [editableDraft]),
      onOpenEditableDraft: (item) async => openedItem = item,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('B-2026-152'));
    await tester.pump();

    expect(openedItem, same(editableDraft));
  });
}

final _workItems = <WorkItem>[
  WorkItem(
    applicationPublicId: 'application-1',
    applicationNumber: 'B-2026-150',
    applicantFullName: 'Ahmet Yılmaz',
    address: 'Bahçelievler Mahallesi No: 4',
    sourceCode: 'OWN_APPLICATION',
    statusCode: 'KURUL_BEKLIYOR',
    isCompleted: false,
    isEditable: false,
    activityAtUtc: DateTime.utc(2026, 8, 10, 9),
  ),
  WorkItem(
    taskId: 2,
    applicationNumber: 'B-2026-151',
    applicantFullName: 'Emel Seçen',
    address: 'Yıldız Mahallesi No: 8',
    sourceCode: 'ASSIGNED_TASK',
    statusCode: 'TAMAMLANDI',
    isCompleted: true,
    isEditable: false,
    activityAtUtc: DateTime.utc(2026, 8, 10, 10),
  ),
];

class _FakeWorkItemsRepository implements WorkItemsRepository {
  _FakeWorkItemsRepository(this._loader);

  final Future<List<WorkItem>> Function() _loader;

  @override
  Future<List<WorkItem>> getMyWorkItems({int limit = 100}) => _loader();
}
