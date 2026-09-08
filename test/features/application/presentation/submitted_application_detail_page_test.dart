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
    expect(find.text('#3751'), findsWidgets);
    expect(find.text('Beklemede'), findsOneWidget);
    expect(find.text('HÜRİYE BUCAK'), findsOneWidget);
    expect(find.text('Gıda Yardımı'), findsOneWidget);
    expect(find.text('Ortopedik'), findsOneWidget);
    expect(
      find.byKey(const Key('application-detail-edit-button')),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      find.text('Aile Bilgileri'),
      250,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('Teyze'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Hane Bilgileri'),
      250,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Mülkiyet Durumu'), findsOneWidget);
    expect(find.text('Kiracı'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Hane Fotoğrafları'),
      250,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Salon fotoğrafı'), findsOneWidget);

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
}

final _details = SubmittedApplicationDetails(
  applicationId: 3751,
  applicationPublicId: '22222222-2222-2222-2222-222222222222',
  applicationNumber: '#3751',
  statusCode: 'KURUL_BEKLIYOR',
  isOwnedByCurrentUser: true,
  isEditable: true,
  applicationDate: DateTime.utc(2026, 9, 7, 10, 30),
  identityNumber: '17611268484',
  firstName: 'HÜRİYE',
  lastName: 'BUCAK',
  birthDate: DateTime(1982, 1, 1),
  phoneNumber: '5345512873',
  helpTypeCode: 'GIDA',
  hasDisability: true,
  disabilityTypeCode: 'ORTOPEDIK',
  description: 'Deneme başvurusudur.',
  fieldInspectionNote: 'Saha notu',
  address: 'ORDUZU MAH. KATMER SK. NO: 7',
  gender: 'Kadın',
  birthPlace: 'KAHTA',
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
  ],
);
