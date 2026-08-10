import 'dart:convert';

import 'package:sosyo_bel/core/auth/auth_tokens.dart';
import 'package:sosyo_bel/core/auth/token_store.dart';
import 'package:sosyo_bel/features/auth/domain/authentication_session.dart';

/// Tokenlarla kullanıcı/belediye kapsamını aynı şifreli kayıtta saklar.
///
/// Tek kayıt kullanılması, token yenilenirken eski kullanıcı bilgisinin yeni
/// tokenlarla eşleşmeden kalması riskini azaltır.
abstract interface class AuthenticationSessionStore implements TokenStore {
  Future<AuthenticationSession?> readSession();

  Future<void> saveSession(AuthenticationSession session);
}

class SecureAuthenticationSessionStore implements AuthenticationSessionStore {
  SecureAuthenticationSessionStore(this._storage);

  factory SecureAuthenticationSessionStore.platform() =>
      SecureAuthenticationSessionStore(FlutterSecureKeyValueStore());

  static const _sessionKey = 'sosyobel.auth.session.v2';
  static const _legacyTokenKey = 'sosyobel.auth.session.v1';

  final SecureKeyValueStore _storage;

  @override
  Future<AuthenticationSession?> readSession() async {
    try {
      final rawValue = await _storage.read(_sessionKey);
      if (rawValue == null || rawValue.isEmpty) {
        // Eski kayıt yalnızca token içerdiği için güvenli profil geri yüklenemez.
        // Bir defalık temizlenir ve kullanıcıdan yeniden giriş istenir.
        if (await _storage.read(_legacyTokenKey) != null) {
          await _storage.delete(_legacyTokenKey);
        }
        return null;
      }

      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic>) {
        await clear();
        return null;
      }

      return AuthenticationSession.fromJson(decoded);
    } on FormatException {
      // Bozuk kayıtla oturum açılmaz; güvenli biçimde temizlenir.
      await clear();
      return null;
    } catch (error) {
      throw TokenStorageException(
        'Güvenli oturum bilgisi okunamadı.',
        cause: error,
      );
    }
  }

  @override
  Future<void> saveSession(AuthenticationSession session) async {
    try {
      await _storage.write(_sessionKey, jsonEncode(session.toJson()));
      // Yeni kayıt başarıyla yazıldıktan sonra eski token kaydı tutulmaz.
      await _storage.delete(_legacyTokenKey);
    } catch (error) {
      throw TokenStorageException(
        'Güvenli oturum bilgisi kaydedilemedi.',
        cause: error,
      );
    }
  }

  @override
  Future<AuthTokens?> read() async => (await readSession())?.tokens;

  @override
  Future<void> save(AuthTokens tokens) async {
    final currentSession = await readSession();
    if (currentSession == null) {
      throw const TokenStorageException(
        'Kullanıcı bilgisi olmadan yalnızca token kaydedilemez.',
      );
    }
    await saveSession(currentSession.copyWith(tokens: tokens));
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(_sessionKey);
      await _storage.delete(_legacyTokenKey);
    } catch (error) {
      throw TokenStorageException(
        'Güvenli oturum bilgisi temizlenemedi.',
        cause: error,
      );
    }
  }
}
