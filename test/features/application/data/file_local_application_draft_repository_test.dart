import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/features/activity/presentation/models/citizen_profile_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/application/data/file_local_application_draft_repository.dart';
import 'package:sosyo_bel/features/application/domain/kps_profile.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

void main() {
  late Directory temporaryDirectory;
  late Directory storageDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'sosyo-bel-local-draft-test-',
    );
    storageDirectory = Directory('${temporaryDirectory.path}/storage');
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  group('FileLocalApplicationDraftRepository', () {
    test(
      'taslağı ve fotoğrafı uygulama yeniden açılmış gibi diskten geri yükler',
      () async {
        final sourcePhoto = await _createPhoto(temporaryDirectory, 'ev.jpg');
        final repository = FileLocalApplicationDraftRepository(
          storageRoot: storageDirectory,
        );

        final created = await repository.create(
          ownerUserId: 'personel-1',
          draft: _fullDraft([HouseholdPhotoViewData.file(sourcePhoto.path)]),
        );
        final copiedPhotoPath =
            created.draft.householdStatus!.photos.single.path;
        expect(copiedPhotoPath, isNot(sourcePhoto.absolute.path));
        expect(await File(copiedPhotoPath).exists(), isTrue);

        // Kaynak kamera dosyasına artık ihtiyaç duyulmadan taslak açılabilmeli.
        await sourcePhoto.delete();
        final reopenedRepository = FileLocalApplicationDraftRepository(
          storageRoot: storageDirectory,
        );
        final restored = await reopenedRepository.read(
          ownerUserId: 'personel-1',
          localDraftId: created.localDraftId,
        );

        expect(restored, isNotNull);
        expect(restored!.ownerUserId, 'personel-1');
        expect(restored.draft.applicationForm?.identityNumber, '12345678901');
        expect(restored.draft.kpsProfile?.fatherName, 'Mehmet');
        expect(restored.draft.citizenProfile.fullName, 'Ayşe Yılmaz');
        expect(
          restored.draft.familyInformation.members.single.details?.vitalStatus,
          'Sağ',
        );
        expect(
          restored.draft.householdStatus?.answers['MULKIYET_DURUMU'],
          'KIRACI',
        );
        expect(
          restored.draft.householdStatus?.saveToBeneficiaryDirectory,
          isTrue,
        );
        expect(restored.draft.completionNote, 'Saha inceleme notu');
        expect(await File(copiedPhotoPath).exists(), isTrue);
      },
    );

    test('bir kullanıcının taslağını başka kullanıcıya göstermez', () async {
      final repository = FileLocalApplicationDraftRepository(
        storageRoot: storageDirectory,
      );
      final created = await repository.create(
        ownerUserId: 'personel-1',
        draft: _fullDraft(),
      );

      expect(await repository.list(ownerUserId: 'personel-2'), isEmpty);
      expect(
        await repository.read(
          ownerUserId: 'personel-2',
          localDraftId: created.localDraftId,
        ),
        isNull,
      );
    });

    test('güncellemede korunan fotoğrafı tutup kaldırılanı temizler', () async {
      var now = DateTime.utc(2026, 8, 26, 10);
      final firstSource = await _createPhoto(temporaryDirectory, 'bir.jpg');
      final secondSource = await _createPhoto(temporaryDirectory, 'iki.jpg');
      final repository = FileLocalApplicationDraftRepository(
        storageRoot: storageDirectory,
        nowUtc: () => now,
      );
      final created = await repository.create(
        ownerUserId: 'personel-1',
        draft: _fullDraft([
          HouseholdPhotoViewData.file(firstSource.path),
          HouseholdPhotoViewData.file(secondSource.path),
        ]),
      );
      final retained = created.draft.householdStatus!.photos.first;
      final removedPath = created.draft.householdStatus!.photos.last.path;

      now = DateTime.utc(2026, 8, 26, 11);
      final updated = await repository.update(
        ownerUserId: 'personel-1',
        localDraftId: created.localDraftId,
        draft: _fullDraft([retained]),
      );

      expect(updated.createdAtUtc, created.createdAtUtc);
      expect(updated.updatedAtUtc, now);
      expect(updated.draft.householdStatus?.photos.single.path, retained.path);
      expect(await File(retained.path).exists(), isTrue);
      expect(await File(removedPath).exists(), isFalse);
    });

    test('15 fotoğraf sınırını aşan taslağı diske yazmaz', () async {
      final source = await _createPhoto(temporaryDirectory, 'ev.jpg');
      final repository = FileLocalApplicationDraftRepository(
        storageRoot: storageDirectory,
      );
      final photos = List<HouseholdPhotoViewData>.generate(
        HouseholdPhotoPolicy.maxPhotoCount + 1,
        (_) => HouseholdPhotoViewData.file(source.path),
      );

      await expectLater(
        repository.create(ownerUserId: 'personel-1', draft: _fullDraft(photos)),
        throwsArgumentError,
      );
      expect(await repository.list(ownerUserId: 'personel-1'), isEmpty);
    });

    test('taslağı fotoğraflarıyla birlikte siler', () async {
      final source = await _createPhoto(temporaryDirectory, 'ev.jpg');
      final repository = FileLocalApplicationDraftRepository(
        storageRoot: storageDirectory,
      );
      final created = await repository.create(
        ownerUserId: 'personel-1',
        draft: _fullDraft([HouseholdPhotoViewData.file(source.path)]),
      );
      final storedPhoto = created.draft.householdStatus!.photos.single.path;

      await repository.delete(
        ownerUserId: 'personel-1',
        localDraftId: created.localDraftId,
      );

      expect(await repository.list(ownerUserId: 'personel-1'), isEmpty);
      expect(await File(storedPhoto).exists(), isFalse);
    });
  });
}

Future<File> _createPhoto(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(const [255, 216, 255, 217], flush: true);
  return file;
}

ApplicationDraft _fullDraft([List<HouseholdPhotoViewData> photos = const []]) {
  return ApplicationDraft(
    applicationForm: const NewApplicationFormData(
      identityNumber: '12345678901',
      birthDate: '01.02.1990',
      disabilityStatusCode: 'YOK',
      disabilityStatus: 'Yok',
      phoneNumber: '05551234567',
      helpTypeCode: 'GIDA',
      helpType: 'Gıda Yardımı',
      description: 'Başvuru açıklaması',
    ),
    kpsProfile: const KpsProfile(
      identityNumber: '12345678901',
      firstName: 'Ayşe',
      lastName: 'Yılmaz',
      fatherName: 'Mehmet',
      motherName: 'Fatma',
      birthDate: '1990-02-01',
      birthPlace: 'Malatya',
      gender: 'Kadın',
      maritalStatus: 'Evli',
      status: 'Açık',
      fullAddress: 'Örnek Mah. Test Sk. No: 1',
    ),
    citizenProfile: const CitizenProfileViewData(
      applicationNumber: '#1',
      fullName: 'Ayşe Yılmaz',
      address: 'Örnek Mah. Test Sk. No: 1',
      phoneNumber: '05551234567',
      identityNumber: '12345678901',
      birthDate: '01.02.1990',
      maritalStatus: 'Evli',
      childrenCount: '1',
      disabilityStatus: 'Yok',
      employmentStatus: 'Çalışmıyor',
      educationStatus: 'Lise',
    ),
    familyInformation: const FamilyInformationViewData(
      members: [
        FamilyMemberViewData(
          fullName: 'Ali Yılmaz',
          relationshipCode: 'COCUK',
          relationship: 'Çocuk',
          age: '12',
          details: FamilyMemberDetailsViewData(
            disabilityStatusCode: 'YOK',
            disabilityStatus: 'Yok',
            employmentStatusCode: 'CALISMIYOR',
            employmentStatus: 'Çalışmıyor',
            educationStatusCode: 'ORTAOKUL',
            educationStatus: 'Ortaokul',
            vitalStatusCode: 'SAG',
            vitalStatus: 'Sağ',
          ),
        ),
      ],
    ),
    householdStatus: HouseholdStatusDraft(
      answers: const {'MULKIYET_DURUMU': 'KIRACI', 'EV_TEMIZLIGI': 'EVET'},
      photos: photos,
      saveToBeneficiaryDirectory: true,
      replaceRemotePhotosOnSave: true,
    ),
    completionNote: 'Saha inceleme notu',
  );
}
