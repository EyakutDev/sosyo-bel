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
    Future<void> Function(WorkItem item)? onOpenSubmittedApplication,
    Future<void> Function(WorkItem item)? onDeleteLocalDraft,
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
          onOpenSubmittedApplication: onOpenSubmittedApplication,
          onDeleteLocalDraft: onDeleteLocalDraft,
        ),
      ),
    );
  }

  testWidgets('API işlerini bekleyen ve tamamlanmış sekmelerine ayırır', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('Hoş geldiniz'), findsOneWidget);
    expect(find.text('Görevlerinizi görüntüleyin'), findsOneWidget);
    final defaultLogo = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('home-municipality-logo')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (defaultLogo.image as AssetImage).assetName,
      AppAssets.battalgaziMunicipalityLogo,
    );
    expect(
      find.bySemanticsLabel('Battalgazi Belediyesi logosu'),
      findsOneWidget,
    );
    expect(find.text('B-2026-150'), findsOneWidget);
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    expect(find.text('Bahçelievler Mahallesi No: 4'), findsOneWidget);
    expect(find.text('Beklemede'), findsOneWidget);
    expect(find.text('B-2026-151'), findsNothing);
    // Gerçek bildirim akışı kurulana kadar görev sayısı bildirim rozeti gibi gösterilmez.
    expect(find.byKey(const Key('home-pending-count')), findsNothing);
    expect(
      find.image(const AssetImage(AppAssets.notificationBell)),
      findsNothing,
    );

    await tester.tap(find.text('Tamamlanan'));
    await tester.pump();

    expect(find.text('B-2026-150'), findsNothing);
    expect(find.text('B-2026-151'), findsOneWidget);
    expect(find.text('Emel Seçen'), findsOneWidget);
    expect(find.text('Tamamlandı'), findsOneWidget);
  });

  testWidgets('sekme göstergesini sürükleyerek tamamlanan listeyi açar', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('home-list-tabs')),
      const Offset(180, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('B-2026-150'), findsNothing);
    expect(find.text('B-2026-151'), findsOneWidget);
  });

  testWidgets('başvurularım filtresi yalnız kendi kayıtlarını gösterir', (
    tester,
  ) async {
    final items = [
      WorkItem(
        applicationId: 101,
        applicationNumber: 'B-OWN-PENDING',
        sourceCode: 'APPLICATION',
        statusCode: 'KURUL_BEKLIYOR',
        isCompleted: false,
        isEditable: true,
        isOwnedByCurrentUser: true,
        activityAtUtc: DateTime.utc(2026, 9, 8, 9),
      ),
      WorkItem(
        applicationId: 102,
        applicationNumber: 'B-OTHER-PENDING',
        sourceCode: 'APPLICATION',
        statusCode: 'KURUL_BEKLIYOR',
        isCompleted: false,
        isEditable: false,
        isOwnedByCurrentUser: false,
        activityAtUtc: DateTime.utc(2026, 9, 8, 10),
      ),
      WorkItem(
        applicationId: 103,
        applicationNumber: 'B-OWN-COMPLETED',
        sourceCode: 'APPLICATION',
        statusCode: 'TAMAMLANDI',
        isCompleted: true,
        isEditable: false,
        isOwnedByCurrentUser: true,
        activityAtUtc: DateTime.utc(2026, 9, 8, 11),
      ),
      WorkItem(
        taskId: 104,
        applicationNumber: 'B-OTHER-COMPLETED',
        sourceCode: 'ASSIGNED_TASK',
        statusCode: 'TAMAMLANDI',
        isCompleted: true,
        isEditable: false,
        isOwnedByCurrentUser: false,
        activityAtUtc: DateTime.utc(2026, 9, 8, 12),
      ),
    ];
    await pumpHome(
      tester,
      repository: _FakeWorkItemsRepository(() async => items),
    );
    await tester.pumpAndSettle();

    expect(find.text('B-OWN-PENDING'), findsOneWidget);
    expect(find.text('B-OTHER-PENDING'), findsOneWidget);
    expect(find.byKey(const Key('home-owned-filter-clear')), findsNothing);

    await tester.tap(find.byKey(const Key('home-owned-filter-button')));
    await tester.pump();

    expect(find.text('B-OWN-PENDING'), findsOneWidget);
    expect(find.text('B-OTHER-PENDING'), findsNothing);
    expect(find.byKey(const Key('home-owned-filter-clear')), findsOneWidget);
    expect(find.text('Yalnızca başvurularınız gösteriliyor'), findsOneWidget);
    final notice = tester.widget<Container>(
      find.byKey(const Key('home-owned-filter-notice')),
    );
    expect((notice.decoration! as BoxDecoration).color, Colors.white);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tamamlanan'));
    await tester.pumpAndSettle();

    expect(find.text('B-OWN-COMPLETED'), findsOneWidget);
    expect(find.text('B-OTHER-COMPLETED'), findsNothing);

    await tester.tap(find.byKey(const Key('home-owned-filter-button')));
    await tester.pumpAndSettle();

    expect(find.text('B-OWN-COMPLETED'), findsOneWidget);
    expect(find.text('B-OTHER-COMPLETED'), findsOneWidget);
  });

  testWidgets('liste sekmelerini ve yuvarlak filtreyi alt alanda gosterir', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();

    final tabs = find.byKey(const Key('home-list-tabs'));
    final filter = find.byKey(const Key('home-owned-filter-button'));
    final filterSize = tester.getSize(filter);

    expect(tester.getCenter(tabs).dy, greaterThan(700));
    expect(find.byKey(const Key('home-bottom-controls')), findsOneWidget);
    expect((filterSize.width - filterSize.height).abs(), lessThan(0.01));
    expect(find.text('Başvurularımı Gör'), findsNothing);
    expect(
      find.byKey(const Key('home-owned-filter-person-icon')),
      findsOneWidget,
    );
  });

  testWidgets('kısa sekme sürüklemesi mevcut listeye geri döner', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('home-list-tabs')),
      const Offset(30, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('B-2026-150'), findsOneWidget);
    expect(find.text('B-2026-151'), findsNothing);
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

  testWidgets('yalnız yerel taslağı onay aldıktan sonra siler', (tester) async {
    final localDraft = WorkItem(
      localDraftId: 'draft-1',
      applicationNumber: 'Yerel Taslak',
      sourceCode: WorkItem.localDraftSourceCode,
      statusCode: 'TASLAK',
      isCompleted: false,
      isEditable: true,
      activityAtUtc: DateTime.utc(2026, 8, 11, 10),
    );
    final items = <WorkItem>[localDraft, _workItems.first];
    WorkItem? deletedItem;
    await pumpHome(
      tester,
      repository: _FakeWorkItemsRepository(() async => items),
      onDeleteLocalDraft: (item) async => deletedItem = item,
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Yerel taslağı sil'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delete-local-draft-draft-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('local-draft-delete-dialog')), findsOneWidget);
    expect(deletedItem, isNull);
    await tester.tap(find.byKey(const Key('local-draft-delete-cancel-button')));
    await tester.pumpAndSettle();
    expect(find.text('Yerel Taslak'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete-local-draft-draft-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('local-draft-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(deletedItem, same(localDraft));
    expect(find.text('Yerel Taslak'), findsNothing);
    expect(find.text('B-2026-150'), findsOneWidget);
    expect(find.text('Yerel taslak silindi.'), findsOneWidget);
  });

  testWidgets('silme başarısız olursa yerel taslağı listede korur', (
    tester,
  ) async {
    final localDraft = WorkItem(
      localDraftId: 'draft-2',
      applicationNumber: 'Yerel Taslak',
      sourceCode: WorkItem.localDraftSourceCode,
      statusCode: 'TASLAK',
      isCompleted: false,
      isEditable: true,
      activityAtUtc: DateTime.utc(2026, 8, 11, 10),
    );
    await pumpHome(
      tester,
      repository: _FakeWorkItemsRepository(() async => [localDraft]),
      onDeleteLocalDraft: (_) async => throw Exception('disk'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-local-draft-draft-2')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('local-draft-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yerel Taslak'), findsOneWidget);
    expect(
      find.text('Yerel taslak silinemedi. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'sunucu basvurusunu duzenlenebilir olmasa da detay callbackine iletir',
    (tester) async {
      WorkItem? openedItem;
      final submittedApplication = WorkItem(
        applicationId: 3751,
        applicationNumber: '#3751',
        applicantFullName: 'Huriye Bucak',
        sourceCode: 'APPLICATION',
        statusCode: 'KURUL_BEKLIYOR',
        isCompleted: false,
        isEditable: false,
        isOwnedByCurrentUser: false,
        activityAtUtc: DateTime.utc(2026, 9, 7, 10),
      );
      await pumpHome(
        tester,
        repository: _FakeWorkItemsRepository(
          () async => [submittedApplication],
        ),
        onOpenSubmittedApplication: (item) async => openedItem = item,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('#3751'));
      await tester.pump();

      expect(openedItem, same(submittedApplication));
    },
  );

  testWidgets('detaydan donuste liste konumunu koruyarak yeniler', (
    tester,
  ) async {
    final items = List<WorkItem>.generate(
      10,
      (index) => WorkItem(
        applicationId: 4000 + index,
        applicationNumber: '#${4000 + index}',
        applicantFullName: 'Basvuru Sahibi $index',
        sourceCode: 'APPLICATION',
        statusCode: 'KURUL_BEKLIYOR',
        isCompleted: false,
        isEditable: false,
        activityAtUtc: DateTime.utc(2026, 9, 8, 10, index),
      ),
    );
    final refreshCompleter = Completer<List<WorkItem>>();
    var loadCount = 0;
    await pumpHome(
      tester,
      repository: _FakeWorkItemsRepository(() {
        loadCount += 1;
        return loadCount == 1
            ? Future<List<WorkItem>>.value(items)
            : refreshCompleter.future;
      }),
      onOpenSubmittedApplication: (_) async {},
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('#4004'), findsOneWidget);

    final scrollable = find.byType(Scrollable);
    final offsetBeforeDetail = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    expect(offsetBeforeDetail, greaterThan(0));

    await tester.tap(find.text('#4004'));
    await tester.pump();

    expect(loadCount, 2);
    expect(find.byKey(const Key('home-loading-indicator')), findsNothing);
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(offsetBeforeDetail, 0.1),
    );

    refreshCompleter.complete(items);
    await tester.pumpAndSettle();

    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(offsetBeforeDetail, 0.1),
    );
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
