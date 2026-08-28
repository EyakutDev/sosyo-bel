import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

/// Telefonda kalıcı olarak saklanan ve yalnız sahibi tarafından görülebilen taslak.
final class LocalApplicationDraftRecord {
  const LocalApplicationDraftRecord({
    required this.localDraftId,
    required this.ownerUserId,
    required this.draft,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final String localDraftId;
  final String ownerUserId;
  final ApplicationDraft draft;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
}

/// Yerel taslakların dosya sistemi ayrıntılarını uygulama akışından gizler.
abstract interface class LocalApplicationDraftRepository {
  Future<LocalApplicationDraftRecord> create({
    required String ownerUserId,
    required ApplicationDraft draft,
  });

  Future<LocalApplicationDraftRecord> update({
    required String ownerUserId,
    required String localDraftId,
    required ApplicationDraft draft,
  });

  Future<LocalApplicationDraftRecord?> read({
    required String ownerUserId,
    required String localDraftId,
  });

  Future<List<LocalApplicationDraftRecord>> list({required String ownerUserId});

  Future<void> delete({
    required String ownerUserId,
    required String localDraftId,
  });
}

class LocalDraftStorageException implements Exception {
  const LocalDraftStorageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

final class LocalDraftNotFoundException extends LocalDraftStorageException {
  const LocalDraftNotFoundException()
    : super('Güncellenecek yerel taslak bulunamadı.');
}
