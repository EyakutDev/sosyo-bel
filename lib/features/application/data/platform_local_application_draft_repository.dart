import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sosyo_bel/features/application/data/file_local_application_draft_repository.dart';
import 'package:sosyo_bel/features/application/domain/local_application_draft_repository.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

typedef ApplicationSupportDirectoryProvider = Future<Directory> Function();

/// Dosya tabanlı taslak deposunu Android ve iOS'un uygulamaya özel destek
/// dizinine bağlar. Dizin ilk işlemde bir kez çözülür ve sonraki işlemlerde aynı
/// repository örneği kullanılır.
final class PlatformLocalApplicationDraftRepository
    implements LocalApplicationDraftRepository {
  PlatformLocalApplicationDraftRepository({
    ApplicationSupportDirectoryProvider? supportDirectoryProvider,
  }) : _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory;

  final ApplicationSupportDirectoryProvider _supportDirectoryProvider;
  Future<FileLocalApplicationDraftRepository>? _delegateFuture;

  Future<FileLocalApplicationDraftRepository> get _delegate =>
      _delegateFuture ??= _createDelegate();

  Future<FileLocalApplicationDraftRepository> _createDelegate() async {
    final applicationSupportDirectory = await _supportDirectoryProvider();
    return FileLocalApplicationDraftRepository(
      storageRoot: Directory(
        p.join(applicationSupportDirectory.path, 'sosyo_bel', 'drafts'),
      ),
    );
  }

  @override
  Future<LocalApplicationDraftRecord> create({
    required String ownerUserId,
    required ApplicationDraft draft,
  }) async {
    return (await _delegate).create(ownerUserId: ownerUserId, draft: draft);
  }

  @override
  Future<void> delete({
    required String ownerUserId,
    required String localDraftId,
  }) async {
    return (await _delegate).delete(
      ownerUserId: ownerUserId,
      localDraftId: localDraftId,
    );
  }

  @override
  Future<List<LocalApplicationDraftRecord>> list({
    required String ownerUserId,
  }) async {
    return (await _delegate).list(ownerUserId: ownerUserId);
  }

  @override
  Future<LocalApplicationDraftRecord?> read({
    required String ownerUserId,
    required String localDraftId,
  }) async {
    return (await _delegate).read(
      ownerUserId: ownerUserId,
      localDraftId: localDraftId,
    );
  }

  @override
  Future<LocalApplicationDraftRecord> update({
    required String ownerUserId,
    required String localDraftId,
    required ApplicationDraft draft,
  }) async {
    return (await _delegate).update(
      ownerUserId: ownerUserId,
      localDraftId: localDraftId,
      draft: draft,
    );
  }
}
