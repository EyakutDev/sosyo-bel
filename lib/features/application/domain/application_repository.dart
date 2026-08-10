import 'package:sosyo_bel/features/application/domain/application_lifecycle_entry.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

/// Başvurunun taslak oluşturma ve kurula gönderme HTTP ayrıntılarını akıştan gizler.
abstract interface class ApplicationRepository {
  Future<ApplicationLifecycleEntry> createDraft({
    required ApplicationDraft draft,
    required String idempotencyKey,
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
