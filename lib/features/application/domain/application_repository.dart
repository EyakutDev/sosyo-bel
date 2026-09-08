import 'dart:typed_data';

import 'package:sosyo_bel/features/application/domain/application_lifecycle_entry.dart';
import 'package:sosyo_bel/features/application/domain/submitted_application_details.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

/// Telefonda tamamlanan başvurunun sunucuya gönderilme ayrıntılarını akıştan gizler.
abstract interface class ApplicationRepository {
  /// Telefonda tamamlanan başvurunun bütün alanlarını ve fotoğraflarını tek
  /// sunucu transactionında kurula gönderir.
  Future<ApplicationLifecycleEntry> submitCompleted({
    required ApplicationDraft draft,
    required String idempotencyKey,
  });

  Future<SubmittedApplicationDetails> getSubmittedDetails({
    required int applicationId,
  });

  Future<Uint8List> getSubmittedPhoto({
    required int applicationId,
    required int photoId,
  });

  Future<SubmittedApplicationUpdateResult> updateSubmitted({
    required int applicationId,
    required ApplicationDraft draft,
  });

  Future<void> deleteSubmitted({required int applicationId});
}
