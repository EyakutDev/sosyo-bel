import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/features/application/domain/submitted_application_details.dart';
import 'package:sosyo_bel/features/application/presentation/submitted_application_detail_page.dart';

import '../../../support/application_reference_test_catalog.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required SubmittedApplicationDetailsLoader loader,
    SubmittedApplicationPhotoLoader? photoLoader,
    VoidCallback? onBack,
    SubmittedApplicationEditor? onEdit,
  }) {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return tester.pumpWidget(
      MaterialApp(
        home: SubmittedApplicationDetailPage(
          applicationNumber: '#3751',
          referenceCatalog: applicationReferenceTestCatalog,
          loadDetails: loader,
          loadPhoto:
              photoLoader ?? (_) async => base64Decode(_onePixelPngBase64),
          onBack: onBack ?? () {},
          onEdit: onEdit,
        ),
      ),
    );
  }

  testWidgets('basvuru detaylarini okunabilir etiketlerle gosterir', (
    tester,
  ) async {
    var backCount = 0;
    await pumpPage(
      tester,
      loader: () async => _details,
      onBack: () => backCount += 1,
    );
    await tester.pumpAndSettle();

    expect(find.text('Başvuru Detayı'), findsOneWidget);
    final bodyClip = tester.widget<ClipRRect>(
      find.byKey(const Key('application-detail-body-clip')),
    );
    expect(
      bodyClip.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(30)),
    );
    expect(bodyClip.clipBehavior, Clip.antiAlias);
    expect(find.text('#3751'), findsWidgets);
    expect(find.text('Beklemede'), findsOneWidget);
    expect(find.text('TEST ÖRNEK'), findsOneWidget);
    expect(find.text('Gıda Yardımı'), findsNothing);
    expect(find.text('Ayşe Yılmaz'), findsNothing);
    expect(
      find.byKey(const Key('application-detail-edit-button')),
      findsNothing,
    );

    final requestSection = find.byKey(
      const Key('application-detail-section-request'),
    );
    await tester.ensureVisible(requestSection);
    await tester.pumpAndSettle();
    await tester.tap(requestSection);
    await tester.pumpAndSettle();
    expect(find.text('TEST ÖRNEK'), findsOneWidget);
    expect(find.text('Gıda Yardımı'), findsOneWidget);
    expect(find.text('Ortopedik'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Aile Bilgileri (2)'),
      250,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(
      find.byKey(const Key('application-detail-section-family')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gıda Yardımı'), findsOneWidget);
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.textContaining('Teyze'), findsOneWidget);
    expect(find.text('Mehmet Örnek'), findsOneWidget);
    expect(find.text('Çalışıyor'), findsNothing);

    await tester.tap(find.byKey(const Key('application-family-toggle-0')));
    await tester.pumpAndSettle();
    expect(find.text('Çalışıyor'), findsOneWidget);

    final secondMember = find.byKey(const Key('application-family-toggle-1'));
    await tester.ensureVisible(secondMember);
    await tester.pumpAndSettle();
    await tester.tap(secondMember);
    await tester.pumpAndSettle();
    expect(find.text('Çalışıyor'), findsNothing);
    expect(find.text('Emekli'), findsOneWidget);

    await tester.tap(secondMember);
    await tester.pumpAndSettle();
    expect(find.text('Emekli'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Hane Bilgileri'),
      250,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(
      find.byKey(const Key('application-detail-section-household')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mülkiyet Durumu'), findsOneWidget);
    expect(find.text('Kiracı'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Hane Fotoğrafları (3)'),
      250,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(
      find.byKey(const Key('application-detail-section-photos')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mülkiyet Durumu'), findsOneWidget);
    expect(find.text('Salon fotoğrafı'), findsOneWidget);
    final thumbnail = find.byKey(const Key('application-photo-thumbnail-91'));
    expect(thumbnail, findsOneWidget);

    await tester.ensureVisible(thumbnail);
    await tester.pumpAndSettle();
    await tester.tap(thumbnail);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('application-photo-preview-91')),
      findsOneWidget,
    );
    expect(find.text('1 / 3'), findsOneWidget);
    expect(
      find.byKey(const Key('application-photo-preview-interactive-91')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const Key('application-photo-preview-gallery')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 / 3'), findsOneWidget);
    final galleryLabel = tester.widget<Text>(
      find.byKey(const ValueKey('application-photo-preview-label-1')),
    );
    expect(galleryLabel.data, 'Mutfak fotoğrafı');
    expect(
      find.byKey(const Key('application-photo-preview-interactive-92')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('application-photo-preview-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('application-detail-back')));
    expect(backCount, 1);
  });

  testWidgets('detay hatasindan sonra yeniden deneyebilir', (tester) async {
    var callCount = 0;
    await pumpPage(
      tester,
      loader: () async {
        callCount += 1;
        if (callCount == 1) {
          throw const ApiException(
            kind: ApiErrorKind.server,
            message: 'Sunucu geçici olarak yanıt vermedi.',
          );
        }
        return _details;
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('Başvuru yüklenemedi'), findsOneWidget);
    expect(find.text('Sunucu geçici olarak yanıt vermedi.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('application-detail-retry')));
    await tester.pumpAndSettle();

    expect(callCount, 2);
    expect(find.byKey(const Key('application-detail-content')), findsOneWidget);
  });

  testWidgets('kendi bekleyen basvurusunu duzenleyip detayi yeniler', (
    tester,
  ) async {
    var loadCount = 0;
    SubmittedApplicationDetails? editedDetails;
    await pumpPage(
      tester,
      loader: () async {
        loadCount += 1;
        return _details;
      },
      onEdit: (details) async {
        editedDetails = details;
        return true;
      },
    );
    await tester.pumpAndSettle();

    final editButton = find.byKey(const Key('application-detail-edit-button'));
    await tester.scrollUntilVisible(
      editButton,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(editedDetails, same(_details));
    expect(loadCount, 2);
  });

  testWidgets('yalniz tam genislikte duzenle butonunu gosterir', (
    tester,
  ) async {
    await pumpPage(
      tester,
      loader: () async => _details,
      onEdit: (_) async => false,
    );
    await tester.pumpAndSettle();

    final editButton = find.byKey(const Key('application-detail-edit-button'));
    await tester.scrollUntilVisible(
      editButton,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('application-detail-delete-button')),
      findsNothing,
    );
    expect(tester.getSize(editButton).width, greaterThan(320));
  });
}

const _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

final _details = SubmittedApplicationDetails(
  applicationId: 3751,
  applicationPublicId: '22222222-2222-2222-2222-222222222222',
  applicationNumber: '#3751',
  statusCode: 'KURUL_BEKLIYOR',
  isOwnedByCurrentUser: true,
  isEditable: true,
  applicationDate: DateTime.utc(2026, 9, 7, 10, 30),
  identityNumber: '10000000146',
  firstName: 'TEST',
  lastName: 'ÖRNEK',
  birthDate: DateTime(1982, 1, 1),
  phoneNumber: '5345512873',
  helpTypeCode: 'GIDA',
  hasDisability: true,
  disabilityTypeCode: 'ORTOPEDIK',
  description: 'Deneme başvurusudur.',
  fieldInspectionNote: 'Saha notu',
  address: 'ÖRNEK MAH. TEST SK. NO: 7',
  gender: 'Kadın',
  birthPlace: 'MERKEZ',
  maritalStatus: 'Evli',
  familyMembers: const [
    SubmittedApplicationFamilyMember(
      fullName: 'Ayşe Yılmaz',
      age: 42,
      relationshipCode: 'DIGER',
      otherRelationshipDescription: 'Teyze',
      hasDisability: false,
      employmentStatusCode: 'CALISIYOR',
      educationStatusCode: 'LISE',
      vitalStatusCode: 'SAG',
    ),
    SubmittedApplicationFamilyMember(
      fullName: 'Mehmet Örnek',
      age: 65,
      relationshipCode: 'BABA',
      hasDisability: false,
      employmentStatusCode: 'EMEKLI',
      educationStatusCode: 'ILKOGRETIM',
      vitalStatusCode: 'SAG',
    ),
  ],
  householdAnswers: const [
    SubmittedApplicationHouseholdAnswer(
      questionCode: 'MULKIYET_DURUMU',
      optionCode: 'KIRACI',
    ),
  ],
  photos: [
    SubmittedApplicationPhoto(
      photoId: 91,
      urlPath:
          '/uploads/hanefotograflari/22222222222222222222222222222222/salon.jpg',
      description: 'Salon fotoğrafı',
      uploadedAt: DateTime.utc(2026, 9, 7, 10, 31),
    ),
    SubmittedApplicationPhoto(
      photoId: 92,
      urlPath:
          '/uploads/hanefotograflari/22222222222222222222222222222222/mutfak.jpg',
      description: 'Mutfak fotoğrafı',
      uploadedAt: DateTime.utc(2026, 9, 7, 10, 32),
    ),
    SubmittedApplicationPhoto(
      photoId: 93,
      urlPath:
          '/uploads/hanefotograflari/22222222222222222222222222222222/banyo.jpg',
      description: 'Banyo fotoğrafı',
      uploadedAt: DateTime.utc(2026, 9, 7, 10, 33),
    ),
  ],
);
