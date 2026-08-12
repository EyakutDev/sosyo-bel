import 'package:sosyo_bel/core/network/api_client.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';

/// Form referanslarını oturum süresince tek kez indirir. Başarısız istek önbelleğe
/// alınmaz; kullanıcı yeniden deneyebilir.
final class RemoteApplicationReferenceRepository
    implements ApplicationReferenceRepository {
  RemoteApplicationReferenceRepository(this._apiClient);

  final ApiClient _apiClient;
  Future<ApplicationReferenceCatalog>? _cachedRequest;

  @override
  Future<ApplicationReferenceCatalog> getCatalog() {
    return _cachedRequest ??= _loadCatalog();
  }

  Future<ApplicationReferenceCatalog> _loadCatalog() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        'api/v1/application-references',
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Referans cevabı boş.');
      }
      return ApplicationReferenceCatalog.fromJson(data);
    } on FormatException {
      _cachedRequest = null;
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'Sunucunun form seçenekleri cevabı geçersiz.',
      );
    } catch (_) {
      _cachedRequest = null;
      rethrow;
    }
  }

  @override
  void clearCache() => _cachedRequest = null;
}
