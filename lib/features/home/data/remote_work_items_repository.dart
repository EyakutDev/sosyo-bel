import 'package:sosyo_bel/core/network/api_client.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/features/home/domain/work_item.dart';
import 'package:sosyo_bel/features/home/domain/work_items_repository.dart';

/// Personelin kendi başvurularını, diğer bekleyen başvuruları ve atanmış
/// görevlerini yetkili birleşik liste endpointinden getirir.
class RemoteWorkItemsRepository implements WorkItemsRepository {
  const RemoteWorkItemsRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<WorkItem>> getMyWorkItems({int limit = 100}) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Limit 1-100 arasında olmalıdır.',
      );
    }

    final response = await _apiClient.get<List<dynamic>>(
      'api/v1/work-items',
      queryParameters: {'limit': limit},
    );
    final data = response.data;
    if (data == null) {
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'Sunucunun iş listesi cevabı boş.',
      );
    }

    try {
      return List.unmodifiable(
        data.map((item) {
          if (item is! Map) {
            throw const FormatException('İş listesi kaydı geçersiz.');
          }
          return WorkItem.fromJson(
            item.map((key, dynamic value) => MapEntry(key.toString(), value)),
          );
        }),
      );
    } on FormatException {
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'Sunucunun iş listesi cevabı geçersiz.',
      );
    }
  }
}
