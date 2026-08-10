import 'package:sosyo_bel/features/auth/domain/authentication_session.dart';

/// Kimlik doğrulamanın HTTP ve güvenli saklama ayrıntılarını ekrandan gizler.
abstract interface class AuthRepository {
  /// Kayıtlı oturumu döndürür; süresi dolan access tokenı gerektiğinde yeniler.
  Future<AuthenticationSession?> restoreSession();

  /// Sunucu oturumunu kapatır ve cihazdaki güvenli kaydı temizler.
  Future<void> logout();

  Future<AuthenticationSession> login({
    required String email,
    required String password,
    String? municipalityCode,
  });
}

/// Backend, aynı hesabın birden fazla belediyeye bağlı olduğunu bildirdiğinde
/// seçim ekranının kullanacağı seçenekleri kaybetmeden taşır.
class MunicipalitySelectionRequiredException implements Exception {
  const MunicipalitySelectionRequiredException(this.municipalities);

  final List<MunicipalityOption> municipalities;

  @override
  String toString() => 'Devam etmek için belediye seçimi gerekiyor.';
}
