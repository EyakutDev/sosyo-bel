import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/auth/auth_tokens.dart';
import 'package:sosyo_bel/core/auth/token_store.dart';
import 'package:sosyo_bel/features/auth/data/authentication_session_store.dart';
import 'package:sosyo_bel/features/auth/domain/authentication_session.dart';

void main() {
  group('SecureAuthenticationSessionStore', () {
    late _MemorySecureKeyValueStore storage;
    late SecureAuthenticationSessionStore sessionStore;

    setUp(() {
      storage = _MemorySecureKeyValueStore();
      sessionStore = SecureAuthenticationSessionStore(storage);
    });

    test(
      'token ve Identity kullanıcısını tek şifreli kayıtta saklar',
      () async {
        final session = _session();

        await sessionStore.saveSession(session);
        final restored = await sessionStore.readSession();

        expect(storage.values.length, 1);
        expect(restored?.tokens.accessToken, 'access-token');
        expect(restored?.user.userId, 'user-1');
        expect(restored?.user.username, 'personel');
        expect(restored?.user.roles, ['Personel']);
      },
    );

    test('bozuk oturum kaydını kabul etmez ve temizler', () async {
      storage.values['sosyobel.auth.session.v3'] = '{bozuk-json';

      expect(await sessionStore.readSession(), isNull);
      expect(storage.values, isEmpty);
    });

    test('eski yalnız-token kaydını temizleyip yeniden giriş ister', () async {
      storage.values['sosyobel.auth.session.v1'] = 'eski-token-kaydi';

      expect(await sessionStore.readSession(), isNull);
      expect(storage.values, isEmpty);
    });

    test('kullanıcı kapsamı olmadan yalnız token kaydetmez', () async {
      expect(
        () => sessionStore.save(_session().tokens),
        throwsA(isA<TokenStorageException>()),
      );
    });
  });
}

AuthenticationSession _session() => AuthenticationSession(
  tokens: AuthTokens(
    accessToken: 'access-token',
    accessTokenExpiresAtUtc: DateTime.utc(2026, 8, 9, 13),
    refreshToken: 'refresh-token',
    refreshTokenExpiresAtUtc: DateTime.utc(2026, 8, 16, 12),
  ),
  user: const AuthenticatedUser(
    userId: 'user-1',
    username: 'personel',
    email: 'test@belediye.com',
    displayName: 'Test Personeli',
    roles: ['Personel'],
  ),
);

class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
