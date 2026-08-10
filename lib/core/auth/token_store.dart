import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sosyo_bel/core/auth/auth_tokens.dart';

/// Oturum tokenlarının saklama ayrıntısını auth ve ağ katmanından gizler.
abstract interface class TokenStore {
  Future<AuthTokens?> read();

  Future<void> save(AuthTokens tokens);

  Future<void> clear();
}

/// Güvenli anahtar-değer deposunu testlerde taklit edilebilir hâle getirir.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Android Keystore ve iOS Keychain kullanan üretim adaptörüdür.
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Access ve refresh tokenı tek şifreli kayıt olarak saklar.
///
/// Tek kayıt kullanılması, uygulama kapanırken tokenlardan yalnız birinin
/// güncellenmiş kalması riskini azaltır.
class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._storage);

  factory SecureTokenStore.platform() =>
      SecureTokenStore(FlutterSecureKeyValueStore());

  static const _sessionKey = 'sosyobel.auth.session.v1';

  final SecureKeyValueStore _storage;

  @override
  Future<AuthTokens?> read() async {
    try {
      final rawValue = await _storage.read(_sessionKey);
      if (rawValue == null || rawValue.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic>) {
        await clear();
        return null;
      }

      return AuthTokens.fromJson(decoded);
    } on FormatException {
      // Bozuk veya eski biçimli kayıtla oturum açılmaz; fail-closed temizlenir.
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
  Future<void> save(AuthTokens tokens) async {
    try {
      await _storage.write(_sessionKey, jsonEncode(tokens.toJson()));
    } catch (error) {
      throw TokenStorageException(
        'Güvenli oturum bilgisi kaydedilemedi.',
        cause: error,
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(_sessionKey);
    } catch (error) {
      throw TokenStorageException(
        'Güvenli oturum bilgisi temizlenemedi.',
        cause: error,
      );
    }
  }
}

class TokenStorageException implements Exception {
  const TokenStorageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'TokenStorageException: $message';
}
