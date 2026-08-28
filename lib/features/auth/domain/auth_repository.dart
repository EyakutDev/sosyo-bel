import 'package:sosyo_bel/features/auth/domain/authentication_session.dart';

/// Kimlik doğrulamanın HTTP ve güvenli saklama ayrıntılarını ekrandan gizler.
abstract interface class AuthRepository {
  /// Kayıtlı oturumu döndürür; süresi dolan access tokenı gerektiğinde yeniler.
  Future<AuthenticationSession?> restoreSession();

  /// Sunucu oturumunu kapatır ve cihazdaki güvenli kaydı temizler.
  Future<void> logout();

  Future<AuthenticationSession> login({
    required String username,
    required String password,
  });
}
