import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:sosyo_bel/core/network/api_client.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/application/data/application_draft_api_mapper.dart';
import 'package:sosyo_bel/features/application/domain/application_lifecycle_entry.dart';
import 'package:sosyo_bel/features/application/domain/application_repository.dart';
import 'package:sosyo_bel/features/application/domain/submitted_application_details.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

/// Telefonda tamamlanan başvuruyu tek atomik HTTP isteğiyle API'ye gönderir.
class RemoteApplicationRepository implements ApplicationRepository {
  const RemoteApplicationRepository(this._apiClient);

  static const _idempotencyHeader = 'Idempotency-Key';

  final ApiClient _apiClient;

  @override
  Future<SubmittedApplicationDetails> getSubmittedDetails({
    required int applicationId,
  }) async {
    _validateApplicationId(applicationId);
    final response = await _apiClient.get<Map<String, dynamic>>(
      'api/v1/applications/$applicationId',
    );
    final data = response.data;
    if (data == null) {
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'Sunucunun başvuru detay cevabı boş.',
      );
    }

    try {
      return SubmittedApplicationDetails.fromJson(data);
    } on FormatException {
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'Sunucunun başvuru detay cevabı geçersiz.',
      );
    }
  }

  @override
  Future<ApplicationLifecycleEntry> submitCompleted({
    required ApplicationDraft draft,
    required String idempotencyKey,
  }) async {
    _validateIdempotencyKey(idempotencyKey);
    try {
      final payload = ApplicationDraftApiMapper.toCompletedSubmissionRequest(
        draft,
      );
      final photos =
          draft.householdStatus?.photos
              .where((photo) => photo.kind == HouseholdPhotoKind.file)
              .toList(growable: false) ??
          const <HouseholdPhotoViewData>[];
      if (photos.length > HouseholdPhotoPolicy.maxPhotoCount) {
        throw const FormatException(HouseholdPhotoPolicy.maxPhotoMessage);
      }

      final formData = FormData();
      formData.fields.add(MapEntry('payload', jsonEncode(payload)));
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
        'api/v1/applications/submit',
        data: formData,
        headers: {_idempotencyHeader: idempotencyKey},
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Sunucunun başvuru cevabı boş.');
      }
      return ApplicationLifecycleEntry.fromCompletedSubmissionJson(data);
    } on FormatException catch (error) {
      throw ApiException(kind: ApiErrorKind.validation, message: error.message);
    }
  }

  @override
  Future<SubmittedApplicationUpdateResult> updateSubmitted({
    required int applicationId,
    required ApplicationDraft draft,
  }) async {
    _validateApplicationId(applicationId);
    late final Map<String, dynamic> payload;
    try {
      payload = ApplicationDraftApiMapper.toSubmittedApplicationUpdateRequest(
        draft,
      );
    } on FormatException catch (error) {
      throw ApiException(kind: ApiErrorKind.validation, message: error.message);
    }

    final response = await _apiClient.put<Map<String, dynamic>>(
      'api/v1/applications/$applicationId',
      data: payload,
    );
    final data = response.data;
    if (data == null) {
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'Sunucunun başvuru güncelleme cevabı boş.',
      );
    }
    try {
      return SubmittedApplicationUpdateResult.fromJson(data);
    } on FormatException {
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'Sunucunun başvuru güncelleme cevabı geçersiz.',
      );
    }
  }

  void _validateApplicationId(int value) {
    if (value <= 0) {
      throw ArgumentError.value(
        value,
        'applicationId',
        'Başvuru kimliği sıfırdan büyük olmalıdır.',
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
}
