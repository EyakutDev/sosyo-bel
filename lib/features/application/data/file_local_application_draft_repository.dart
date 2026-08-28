import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/application/data/application_draft_local_codec.dart';
import 'package:sosyo_bel/features/application/domain/local_application_draft_repository.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

/// Taslakları ve taslağa ait fotoğrafları uygulamanın özel dosya alanında saklar.
///
/// [storageRoot] platforma bağlı değildir. Uygulama katmanı daha sonra Android ve
/// iOS için uygulamaya özel dizini sağlayabilir; testler ise geçici bir dizin verir.
final class FileLocalApplicationDraftRepository
    implements LocalApplicationDraftRepository {
  FileLocalApplicationDraftRepository({
    required Directory storageRoot,
    DateTime Function()? nowUtc,
  }) : _storageRoot = Directory(p.normalize(p.absolute(storageRoot.path))),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  static const _schemaVersion = 1;
  static const _manifestName = 'draft.json';
  static const _backupManifestName = 'draft.json.bak';
  static final _draftIdPattern = RegExp(r'^[a-f0-9]{32}$');

  final Directory _storageRoot;
  final DateTime Function() _nowUtc;
  final Random _random = Random.secure();

  // Aynı repository örneğindeki eş zamanlı işlemlerin manifest ve fotoğraf
  // dosyalarını birbiriyle yarışarak değiştirmesini engeller.
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<LocalApplicationDraftRecord> create({
    required String ownerUserId,
    required ApplicationDraft draft,
  }) => _exclusive(
    () => _translateFileErrors(
      'Yerel taslak oluşturulamadı.',
      () => _create(ownerUserId: ownerUserId, draft: draft),
    ),
  );

  @override
  Future<LocalApplicationDraftRecord> update({
    required String ownerUserId,
    required String localDraftId,
    required ApplicationDraft draft,
  }) => _exclusive(
    () => _translateFileErrors(
      'Yerel taslak güncellenemedi.',
      () => _update(
        ownerUserId: ownerUserId,
        localDraftId: localDraftId,
        draft: draft,
      ),
    ),
  );

  @override
  Future<LocalApplicationDraftRecord?> read({
    required String ownerUserId,
    required String localDraftId,
  }) => _exclusive(
    () => _translateFileErrors(
      'Yerel taslak okunamadı.',
      () => _read(ownerUserId: ownerUserId, localDraftId: localDraftId),
    ),
  );

  @override
  Future<List<LocalApplicationDraftRecord>> list({
    required String ownerUserId,
  }) => _exclusive(
    () => _translateFileErrors(
      'Yerel taslaklar okunamadı.',
      () => _list(ownerUserId: ownerUserId),
    ),
  );

  @override
  Future<void> delete({
    required String ownerUserId,
    required String localDraftId,
  }) => _exclusive(
    () => _translateFileErrors(
      'Yerel taslak silinemedi.',
      () => _delete(ownerUserId: ownerUserId, localDraftId: localDraftId),
    ),
  );

  Future<LocalApplicationDraftRecord> _create({
    required String ownerUserId,
    required ApplicationDraft draft,
  }) async {
    final owner = _validateOwnerUserId(ownerUserId);
    _validatePhotoCount(draft);
    await _validateSourcePhotos(draft);

    final draftsDirectory = _draftsDirectory(owner);
    await draftsDirectory.create(recursive: true);
    final localDraftId = await _newDraftId(draftsDirectory);
    final draftDirectory = _draftDirectory(owner, localDraftId);
    await draftDirectory.create();

    try {
      final storedDraft = await _copyExternalPhotos(
        draft: draft,
        draftDirectory: draftDirectory,
        retainedPhotoPaths: const <String>{},
      );
      final timestamp = _nowUtc().toUtc();
      final record = LocalApplicationDraftRecord(
        localDraftId: localDraftId,
        ownerUserId: owner,
        draft: storedDraft,
        createdAtUtc: timestamp,
        updatedAtUtc: timestamp,
      );
      await _writeManifest(draftDirectory, record);
      return record;
    } catch (_) {
      if (await draftDirectory.exists()) {
        await draftDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<LocalApplicationDraftRecord> _update({
    required String ownerUserId,
    required String localDraftId,
    required ApplicationDraft draft,
  }) async {
    final owner = _validateOwnerUserId(ownerUserId);
    _validateDraftId(localDraftId);
    _validatePhotoCount(draft);
    await _validateSourcePhotos(draft);

    final current = await _read(ownerUserId: owner, localDraftId: localDraftId);
    if (current == null) throw const LocalDraftNotFoundException();

    final draftDirectory = _draftDirectory(owner, localDraftId);
    final retainedPhotoPaths = _filePhotoPaths(
      current.draft,
    ).map((path) => p.normalize(p.absolute(path))).toSet();
    final storedDraft = await _copyExternalPhotos(
      draft: draft,
      draftDirectory: draftDirectory,
      retainedPhotoPaths: retainedPhotoPaths,
    );
    final record = LocalApplicationDraftRecord(
      localDraftId: localDraftId,
      ownerUserId: owner,
      draft: storedDraft,
      createdAtUtc: current.createdAtUtc,
      updatedAtUtc: _nowUtc().toUtc(),
    );

    await _writeManifest(draftDirectory, record);
    await _deleteUnreferencedPhotos(draftDirectory, storedDraft);
    return record;
  }

  Future<LocalApplicationDraftRecord?> _read({
    required String ownerUserId,
    required String localDraftId,
  }) async {
    final owner = _validateOwnerUserId(ownerUserId);
    _validateDraftId(localDraftId);
    final draftDirectory = _draftDirectory(owner, localDraftId);
    if (!await draftDirectory.exists()) return null;

    final manifestFile = await _recoverManifestIfNecessary(draftDirectory);
    if (!await manifestFile.exists()) {
      throw const FormatException('Yerel taslak manifesti bulunamadı.');
    }

    final decoded = jsonDecode(await manifestFile.readAsString());
    final manifest = _asMap(decoded, 'manifest');
    if (manifest['schemaVersion'] != _schemaVersion) {
      throw const FormatException('Yerel taslak sürümü desteklenmiyor.');
    }
    if (_requiredString(manifest, 'localDraftId') != localDraftId) {
      throw const FormatException('Yerel taslak kimliği uyuşmuyor.');
    }
    if (_requiredString(manifest, 'ownerUserId') != owner) {
      throw const FormatException('Yerel taslak sahibi uyuşmuyor.');
    }

    final draft = ApplicationDraftLocalCodec.fromJson(
      _requiredMap(manifest, 'draft'),
      decodeFilePhotoPath: (storedPath) =>
          _resolveStoredPhotoPath(draftDirectory, storedPath),
    );
    return LocalApplicationDraftRecord(
      localDraftId: localDraftId,
      ownerUserId: owner,
      draft: draft,
      createdAtUtc: _requiredUtcDateTime(manifest, 'createdAtUtc'),
      updatedAtUtc: _requiredUtcDateTime(manifest, 'updatedAtUtc'),
    );
  }

  Future<List<LocalApplicationDraftRecord>> _list({
    required String ownerUserId,
  }) async {
    final owner = _validateOwnerUserId(ownerUserId);
    final draftsDirectory = _draftsDirectory(owner);
    if (!await draftsDirectory.exists()) return const [];

    final records = <LocalApplicationDraftRecord>[];
    await for (final entity in draftsDirectory.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      if (!_draftIdPattern.hasMatch(id)) continue;
      final record = await _read(ownerUserId: owner, localDraftId: id);
      if (record != null) records.add(record);
    }
    records.sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
    return List.unmodifiable(records);
  }

  Future<void> _delete({
    required String ownerUserId,
    required String localDraftId,
  }) async {
    final owner = _validateOwnerUserId(ownerUserId);
    _validateDraftId(localDraftId);
    final draftDirectory = _draftDirectory(owner, localDraftId);
    if (await draftDirectory.exists()) {
      await draftDirectory.delete(recursive: true);
    }
  }

  Future<ApplicationDraft> _copyExternalPhotos({
    required ApplicationDraft draft,
    required Directory draftDirectory,
    required Set<String> retainedPhotoPaths,
  }) async {
    final householdStatus = draft.householdStatus;
    if (householdStatus == null) return draft;

    final photosDirectory = Directory(p.join(draftDirectory.path, 'photos'));
    final storedPhotos = <HouseholdPhotoViewData>[];
    for (final photo in householdStatus.photos) {
      if (photo.kind == HouseholdPhotoKind.asset) {
        storedPhotos.add(photo);
        continue;
      }

      final sourcePath = p.normalize(p.absolute(photo.path));
      if (retainedPhotoPaths.contains(sourcePath) &&
          _isInsideDirectory(photosDirectory, sourcePath)) {
        storedPhotos.add(HouseholdPhotoViewData.file(sourcePath));
        continue;
      }

      await photosDirectory.create(recursive: true);
      final source = File(sourcePath);
      final extension = _safeExtension(sourcePath);
      final target = File(
        p.join(photosDirectory.path, '${_randomHex(16)}$extension'),
      );
      await source.copy(target.path);
      storedPhotos.add(
        HouseholdPhotoViewData.file(p.normalize(p.absolute(target.path))),
      );
    }

    return ApplicationDraft(
      applicationForm: draft.applicationForm,
      kpsProfile: draft.kpsProfile,
      citizenProfile: draft.citizenProfile,
      familyInformation: draft.familyInformation,
      householdStatus: HouseholdStatusDraft(
        answers: Map.unmodifiable(householdStatus.answers),
        photos: List.unmodifiable(storedPhotos),
        saveToBeneficiaryDirectory: householdStatus.saveToBeneficiaryDirectory,
        replaceRemotePhotosOnSave: householdStatus.replaceRemotePhotosOnSave,
      ),
      completionNote: draft.completionNote,
    );
  }

  Future<void> _writeManifest(
    Directory draftDirectory,
    LocalApplicationDraftRecord record,
  ) async {
    final manifestFile = File(p.join(draftDirectory.path, _manifestName));
    final backupFile = File(p.join(draftDirectory.path, _backupManifestName));
    final temporaryFile = File(
      p.join(draftDirectory.path, '$_manifestName.${_randomHex(8)}.tmp'),
    );
    final manifest = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'localDraftId': record.localDraftId,
      'ownerUserId': record.ownerUserId,
      'createdAtUtc': record.createdAtUtc.toUtc().toIso8601String(),
      'updatedAtUtc': record.updatedAtUtc.toUtc().toIso8601String(),
      'draft': ApplicationDraftLocalCodec.toJson(
        record.draft,
        encodeFilePhotoPath: (absolutePath) =>
            _storedPhotoPath(draftDirectory, absolutePath),
      ),
    };

    await temporaryFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
      flush: true,
    );
    var backupCreated = false;
    try {
      if (await backupFile.exists()) await backupFile.delete();
      if (await manifestFile.exists()) {
        await manifestFile.rename(backupFile.path);
        backupCreated = true;
      }
      await temporaryFile.rename(manifestFile.path);
      if (backupCreated && await backupFile.exists()) {
        await backupFile.delete();
      }
    } catch (_) {
      if (!await manifestFile.exists() && await backupFile.exists()) {
        await backupFile.rename(manifestFile.path);
      }
      rethrow;
    } finally {
      if (await temporaryFile.exists()) await temporaryFile.delete();
    }
  }

  Future<File> _recoverManifestIfNecessary(Directory draftDirectory) async {
    final manifestFile = File(p.join(draftDirectory.path, _manifestName));
    final backupFile = File(p.join(draftDirectory.path, _backupManifestName));
    if (!await manifestFile.exists() && await backupFile.exists()) {
      await backupFile.rename(manifestFile.path);
    }
    return manifestFile;
  }

  Future<void> _deleteUnreferencedPhotos(
    Directory draftDirectory,
    ApplicationDraft storedDraft,
  ) async {
    final photosDirectory = Directory(p.join(draftDirectory.path, 'photos'));
    if (!await photosDirectory.exists()) return;

    final referenced = _filePhotoPaths(
      storedDraft,
    ).map((path) => p.normalize(p.absolute(path))).toSet();
    await for (final entity in photosDirectory.list(followLinks: false)) {
      if (entity is! File || referenced.contains(p.normalize(entity.path))) {
        continue;
      }
      // Manifest artık yeni veriyi gösterir. Eski bir fotoğraf silinemezse kayıt
      // geçersiz sayılmaz; dosya yalnızca zararsız bir artık olarak kalır.
      try {
        await entity.delete();
      } on FileSystemException {
        // Bir sonraki güncellemede temizleme yeniden denenir.
      }
    }
  }

  Future<void> _validateSourcePhotos(ApplicationDraft draft) async {
    for (final path in _filePhotoPaths(draft)) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type != FileSystemEntityType.file) {
        throw ArgumentError.value(path, 'photo.path', 'Fotoğraf bulunamadı.');
      }
    }
  }

  void _validatePhotoCount(ApplicationDraft draft) {
    final count = draft.householdStatus?.photos.length ?? 0;
    if (count > HouseholdPhotoPolicy.maxPhotoCount) {
      throw ArgumentError(HouseholdPhotoPolicy.maxPhotoMessage);
    }
  }

  Iterable<String> _filePhotoPaths(ApplicationDraft draft) sync* {
    for (final photo in draft.householdStatus?.photos ?? const []) {
      if (photo.kind == HouseholdPhotoKind.file) yield photo.path;
    }
  }

  String _storedPhotoPath(Directory draftDirectory, String absolutePath) {
    final photosDirectory = Directory(p.join(draftDirectory.path, 'photos'));
    final normalized = p.normalize(p.absolute(absolutePath));
    if (!_isInsideDirectory(photosDirectory, normalized)) {
      throw const FormatException('Taslak fotoğrafı güvenli dizinde değil.');
    }
    return p
        .relative(normalized, from: draftDirectory.path)
        .replaceAll('\\', '/');
  }

  String _resolveStoredPhotoPath(Directory draftDirectory, String storedPath) {
    if (storedPath.trim().isEmpty || p.isAbsolute(storedPath)) {
      throw const FormatException('Yerel fotoğraf yolu geçersiz.');
    }
    final platformPath = storedPath.replaceAll('/', p.separator);
    final resolved = p.normalize(
      p.absolute(p.join(draftDirectory.path, platformPath)),
    );
    final photosDirectory = Directory(p.join(draftDirectory.path, 'photos'));
    if (!_isInsideDirectory(photosDirectory, resolved)) {
      throw const FormatException(
        'Yerel fotoğraf yolu güvenli dizinin dışında.',
      );
    }
    if (FileSystemEntity.typeSync(resolved, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('Yerel taslak fotoğrafı bulunamadı.');
    }
    return resolved;
  }

  bool _isInsideDirectory(Directory directory, String candidatePath) {
    final root = p.normalize(p.absolute(directory.path));
    final candidate = p.normalize(p.absolute(candidatePath));
    return p.isWithin(root, candidate);
  }

  Directory _draftsDirectory(String ownerUserId) => Directory(
    p.join(
      _storageRoot.path,
      'users',
      sha256.convert(utf8.encode(ownerUserId)).toString(),
      'drafts',
    ),
  );

  Directory _draftDirectory(String ownerUserId, String localDraftId) =>
      Directory(p.join(_draftsDirectory(ownerUserId).path, localDraftId));

  Future<String> _newDraftId(Directory draftsDirectory) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final id = _randomHex(16);
      if (!await Directory(p.join(draftsDirectory.path, id)).exists()) {
        return id;
      }
    }
    throw const LocalDraftStorageException(
      'Benzersiz yerel taslak kimliği üretilemedi.',
    );
  }

  String _randomHex(int byteCount) {
    final bytes = List<int>.generate(byteCount, (_) => _random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  String _safeExtension(String filePath) {
    final extension = p.extension(filePath).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,10}$').hasMatch(extension) ? extension : '';
  }

  String _validateOwnerUserId(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        value,
        'ownerUserId',
        'Kullanıcı kimliği boş olamaz.',
      );
    }
    return normalized;
  }

  void _validateDraftId(String value) {
    if (!_draftIdPattern.hasMatch(value)) {
      throw ArgumentError.value(
        value,
        'localDraftId',
        'Taslak kimliği geçersiz.',
      );
    }
  }

  Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) =>
      _asMap(json[key], key);

  Map<String, dynamic> _asMap(Object? value, String fieldName) {
    if (value is! Map) throw FormatException('$fieldName alanı geçersiz.');
    return value.map((key, dynamic item) => MapEntry(key.toString(), item));
  }

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) throw FormatException('$key alanı geçersiz.');
    return value;
  }

  DateTime _requiredUtcDateTime(Map<String, dynamic> json, String key) {
    final value = _requiredString(json, key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc) {
      throw FormatException('$key alanı geçersiz.');
    }
    return parsed;
  }

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    final previous = _operationTail;
    final release = Completer<void>();
    _operationTail = release.future;
    await previous;
    try {
      return await operation();
    } finally {
      release.complete();
    }
  }

  Future<T> _translateFileErrors<T>(
    String message,
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } on LocalDraftStorageException {
      rethrow;
    } on FileSystemException catch (error) {
      throw LocalDraftStorageException(message, cause: error);
    } on FormatException catch (error) {
      throw LocalDraftStorageException(
        'Telefondaki taslak verisi okunamadı.',
        cause: error,
      );
    }
  }
}
