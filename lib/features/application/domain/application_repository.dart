import 'package:sosyo_bel/features/application/domain/application_lifecycle_entry.dart';
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

/// Başvurunun taslak oluşturma ve kurula gönderme HTTP ayrıntılarını akıştan gizler.
abstract interface class ApplicationRepository {
  Future<LoadedApplicationDraft> getDraft({
    required String applicationPublicId,
    required ApplicationReferenceCatalog referenceCatalog,
  });

  Future<ApplicationLifecycleEntry> createDraft({
    required ApplicationDraft draft,
    required String idempotencyKey,
  });

  Future<ApplicationLifecycleEntry> updateDraft({
    required ApplicationDraft draft,
    required String applicationPublicId,
    required String expectedRowVersion,
  });

  Future<ApplicationLifecycleEntry> saveFieldData({
    required ApplicationDraft draft,
    required String applicationPublicId,
    required String expectedRowVersion,
  });

  Future<ApplicationLifecycleEntry> uploadPhotos({
    required ApplicationDraft draft,
    required String applicationPublicId,
    required String expectedRowVersion,
    required String idempotencyKey,
  });

  Future<ApplicationLifecycleEntry> submitToBoard({
    required String applicationPublicId,
    required String expectedRowVersion,
    required String idempotencyKey,
  });
}

/// Sunucudan geri okunan ekran taslağı ile yazma işlemlerinde kullanılacak yaşam
/// döngüsü bilgisini birbirinden ayırmadan taşır.
class LoadedApplicationDraft {
  const LoadedApplicationDraft({required this.entry, required this.draft});

  final ApplicationLifecycleEntry entry;
  final ApplicationDraft draft;
}
