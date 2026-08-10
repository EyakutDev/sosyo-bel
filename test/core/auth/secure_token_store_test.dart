import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/auth/auth_tokens.dart';
import 'package:sosyo_bel/core/auth/token_store.dart';

void main() {
  group('SecureTokenStore', () {
    late _MemorySecureKeyValueStore storage;
    late SecureTokenStore tokenStore;

    setUp(() {
      storage = _MemorySecureKeyValueStore();
      tokenStore = SecureTokenStore(storage);
    });

    test('access ve refresh tokenı birlikte kaydedip okur', () async {
      final tokens = _tokens();

      await tokenStore.save(tokens);
      final restored = await tokenStore.read();

      expect(restored?.accessToken, tokens.accessToken);
      expect(restored?.refreshToken, tokens.refreshToken);
      expect(restored?.accessTokenExpiresAtUtc, tokens.accessTokenExpiresAtUtc);
      expect(
        restored?.refreshTokenExpiresAtUtc,
        tokens.refreshTokenExpiresAtUtc,
      );
    });

    test('clear güvenli kaydı siler', () async {
      await tokenStore.save(_tokens());

      await tokenStore.clear();

      expect(await tokenStore.read(), isNull);
    });

    test('bozuk kaydı oturum olarak kabul etmez ve temizler', () async {
      storage.value = jsonEncode({'accessToken': 'eksik'});

      expect(await tokenStore.read(), isNull);
      expect(storage.value, isNull);
    });
  });

  group('AuthTokens', () {
    test('token sürelerinin dolup dolmadığını UTC üzerinden hesaplar', () {
      final now = DateTime.utc(2026, 8, 9, 12);
      final tokens = AuthTokens(
        accessToken: 'access-token',
        accessTokenExpiresAtUtc: now,
        refreshToken: 'refresh-token',
        refreshTokenExpiresAtUtc: now.add(const Duration(days: 1)),
      );

      expect(tokens.isAccessTokenExpired(now), isTrue);
      expect(tokens.isRefreshTokenExpired(now), isFalse);
    });
  });
}

AuthTokens _tokens() => AuthTokens(
  accessToken: 'access-token',
  accessTokenExpiresAtUtc: DateTime.utc(2026, 8, 9, 12, 30),
  refreshToken: 'refresh-token',
  refreshTokenExpiresAtUtc: DateTime.utc(2026, 8, 16, 12),
);

class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  String? value;

  @override
  Future<void> delete(String key) async {
    value = null;
  }

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async {
    this.value = value;
  }
}
