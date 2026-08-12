import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:sosyo_bel/core/network/api_client.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/application/data/application_draft_api_mapper.dart';
import 'package:sosyo_bel/features/application/data/application_draft_snapshot_mapper.dart';
import 'package:sosyo_bel/features/application/domain/application_lifecycle_entry.dart';
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';
import 'package:sosyo_bel/features/application/domain/application_repository.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

/// Basvuru taslagini, saha verisini, fotograflari ve kurul gonderimini API'ye baglar.
class RemoteApplicationRepository implements ApplicationRepository {
  const RemoteApplicationRepository(this._apiClient);

  static const _idempotencyHeader = 'Idempotency-Key';

  final ApiClient _apiClient;

  @override
  Future<LoadedApplicationDraft> getDraft({
    required String applicationPublicId,
    required ApplicationReferenceCatalog referenceCatalog,
  }) async {
    Directory? downloadDirectory;
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        'api/v1/applications/$applicationPublicId/draft-snapshot',
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Sunucunun taslak cevabı boş.');
      }

      final references = ApplicationDraftSnapshotMapper.readPhotoReferences(
        data,
      );
      final photos = <HouseholdPhotoViewData>[];
      if (references.isNotEmpty) {
        downloadDirectory = await Directory.systemTemp.createTemp(
          'sosyo-bel-draft-',
        );
      }
      for (final reference in references) {
        final photoResponse = await _apiClient.getBytes(
          'api/v1/applications/$applicationPublicId/photos/${reference.photoId}',
        );
        final bytes = photoResponse.data;
        if (bytes == null || bytes.length != reference.length) {
          throw const FormatException('Fotoğraf içeriği eksik indirildi.');
        }
        final extension = _extensionForContentType(reference.contentType);
        final file = File(
          '${downloadDirectory!.path}${Platform.pathSeparator}'
          '${reference.order.toString().padLeft(2, '0')}-'
          '${reference.photoId}$extension',
        );
        await file.writeAsBytes(bytes, flush: true);
        photos.add(HouseholdPhotoViewData.file(file.path));
      }
      return ApplicationDraftSnapshotMapper.fromJson(
        data,
        photos: photos,
        referenceCatalog: referenceCatalog,
      );
    } on FormatException catch (_) {
      if (downloadDirectory != null && await downloadDirectory.exists()) {
        await downloadDirectory.delete(recursive: true);
      }
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'Sunucunun taslak cevabı geçersiz.',
      );
    } catch (_) {
      if (downloadDirectory != null && await downloadDirectory.exists()) {
        await downloadDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  @override
  Future<ApplicationLifecycleEntry> createDraft({
    required ApplicationDraft draft,
    required String idempotencyKey,
  }) async {
    _validateIdempotencyKey(idempotencyKey);
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        'api/v1/applications/drafts',
        data: ApplicationDraftApiMapper.toCreateRequest(draft),
        headers: {_idempotencyHeader: idempotencyKey},
      );
      return _readEntry(response.data);
    } on FormatException catch (error) {
      throw ApiException(kind: ApiErrorKind.validation, message: error.message);
    }
  }

  @override
  Future<ApplicationLifecycleEntry> updateDraft({
    required ApplicationDraft draft,
    required String applicationPublicId,
    required String expectedRowVersion,
  }) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        'api/v1/applications/$applicationPublicId/draft',
        data: {
          'expectedRowVersion': expectedRowVersion,
          ...ApplicationDraftApiMapper.toCreateRequest(draft),
        },
      );
      return _readEntry(response.data);
    } on FormatException catch (error) {
      throw ApiException(kind: ApiErrorKind.validation, message: error.message);
    }
  }

  @override
  Future<ApplicationLifecycleEntry> saveFieldData({
    required ApplicationDraft draft,
    required String applicationPublicId,
    required String expectedRowVersion,
  }) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        'api/v1/applications/$applicationPublicId/field-data',
        data: ApplicationDraftApiMapper.toFieldDataRequest(
          draft,
          expectedRowVersion: expectedRowVersion,
        ),
      );
      return _readEntry(response.data);
    } on FormatException catch (error) {
      throw ApiException(kind: ApiErrorKind.validation, message: error.message);
    }
  }

  @override
  Future<ApplicationLifecycleEntry> uploadPhotos({
    required ApplicationDraft draft,
    required String applicationPublicId,
    required String expectedRowVersion,
    required String idempotencyKey,
  }) async {
    _validateIdempotencyKey(idempotencyKey);
    final photos =
        draft.householdStatus?.photos
            .where((photo) => photo.kind == HouseholdPhotoKind.file)
            .toList(growable: false) ??
        const <HouseholdPhotoViewData>[];
    // Boş koleksiyon, sunucudan yeniden açılan taslaktaki tüm fotoğrafların
    // kullanıcı tarafından silindiğini ifade edebilir. Bu nedenle geçerli bir
    // snapshot değiştirme isteğidir.
    final formData = FormData();
    formData.fields.add(MapEntry('expectedRowVersion', expectedRowVersion));
    for (final photo in photos) {
      final file = File(photo.path);
      formData.files.add(
        MapEntry(
          'photos',
          await MultipartFile.fromFile(
            file.path,
            filename: file.uri.pathSegments.last,
            contentType: _photoContentType(file.path),
          ),
        ),
      );
    }

    final response = await _apiClient.post<Map<String, dynamic>>(
      'api/v1/applications/$applicationPublicId/photos',
      data: formData,
      headers: {_idempotencyHeader: idempotencyKey},
    );
    return _readEntry(response.data);
  }

  @override
  Future<ApplicationLifecycleEntry> submitToBoard({
    required String applicationPublicId,
    required String expectedRowVersion,
    required String idempotencyKey,
  }) async {
    _validateIdempotencyKey(idempotencyKey);
    final response = await _apiClient.post<Map<String, dynamic>>(
      'api/v1/applications/$applicationPublicId/submit',
      data: {'expectedRowVersion': expectedRowVersion},
      headers: {_idempotencyHeader: idempotencyKey},
    );
    return _readEntry(response.data);
  }

  ApplicationLifecycleEntry _readEntry(Map<String, dynamic>? data) {
    if (data == null) {
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'Sunucunun başvuru cevabı boş.',
      );
    }
    try {
      return ApplicationLifecycleEntry.fromJson(data);
    } on FormatException {
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'Sunucunun başvuru cevabı geçersiz.',
      );
    }
  }

  void _validateIdempotencyKey(String value) {
    final length = value.trim().length;
    if (length < 8 || length > 100) {
      throw ArgumentError.value(
        value,
        'idempotencyKey',
        'İstek anahtarı 8-100 karakter arasında olmalıdır.',
      );
    }
  }

  MediaType _photoContentType(String path) {
    final extension = path.toLowerCase().split('.').last;
    return switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'heic' => MediaType('image', 'heic'),
      'heif' => MediaType('image', 'heif'),
      _ => throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Yalnız JPEG, PNG, HEIC veya HEIF fotoğraf yüklenebilir.',
      ),
    };
  }

  String _extensionForContentType(String contentType) {
    return switch (contentType.toLowerCase()) {
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'image/heic' => '.heic',
      'image/heif' => '.heif',
      _ => throw const FormatException('Fotoğraf içerik türü desteklenmiyor.'),
    };
  }
}
