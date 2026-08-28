import 'package:sosyo_bel/core/auth/auth_tokens.dart';
import 'package:sosyo_bel/core/network/api_client.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/features/auth/data/authentication_session_store.dart';
import 'package:sosyo_bel/features/auth/domain/auth_repository.dart';
import 'package:sosyo_bel/features/auth/domain/authentication_session.dart';

/// Sosyo-Bel kimlik doğrulama endpoint'lerini kullanan üretim repository'si.
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required ApiClient apiClient,
    required AuthenticationSessionStore sessionStore,
    DateTime Function()? nowUtc,
  }) : _apiClient = apiClient,
       _sessionStore = sessionStore,
       _nowUtc = nowUtc ?? _currentUtc;

  final ApiClient _apiClient;
  final AuthenticationSessionStore _sessionStore;
  final DateTime Function() _nowUtc;

  static DateTime _currentUtc() => DateTime.now().toUtc();

  @override
  Future<void> logout() async {
    final session = await _sessionStore.readSession();
    try {
      if (session != null) {
        await _apiClient.post<void>(
          'api/v1/auth/logout',
          data: {'refreshToken': session.tokens.refreshToken},
          // Access tokenın süresi dolmuş olsa da logout endpoint'i anonimdir.
          skipAuthorization: true,
        );
      }
    } finally {
      // Sunucuya ulaşılamasa bile token bu cihazda kullanılabilir kalmaz.
      await _sessionStore.clear();
    }
  }

  @override
  Future<AuthenticationSession?> restoreSession() async {
    final session = await _sessionStore.readSession();
    if (session == null) return null;

    final nowUtc = _nowUtc().toUtc();
    if (session.tokens.isRefreshTokenExpired(nowUtc)) {
      await _sessionStore.clear();
      return null;
    }
    if (!session.tokens.isAccessTokenExpired(nowUtc)) {
      return session;
    }

    return _refreshSession(session);
  }

  /// Uygulama açıkken dolan access tokenı korumalı istekten hemen önce yeniler.
  Future<AuthTokens?> refreshAccessTokens() async {
    final session = await _sessionStore.readSession();
    if (session == null) return null;

    final nowUtc = _nowUtc().toUtc();
    if (session.tokens.isRefreshTokenExpired(nowUtc)) {
      await _sessionStore.clear();
      return null;
    }

    final refreshed = await _refreshSession(session);
    return refreshed?.tokens;
  }

  @override
  Future<AuthenticationSession> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        'api/v1/auth/login',
        data: {'username': username.trim(), 'password': password},
        // Login endpoint'i anonimdir; eski bir token yanlışlıkla gönderilmez.
        skipAuthorization: true,
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Giriş cevabı boş olamaz.');
      }

      // Token ancak bütün cevap başarıyla ayrıştırıldıktan sonra kalıcılaşır.
      final session = AuthenticationSession.fromJson(data);
      await _sessionStore.saveSession(session);
      return session;
    } on FormatException {
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message:
            'Sunucunun giriş cevabı geçersiz. Lütfen yöneticinize bildirin.',
      );
    }
  }

  Future<AuthenticationSession?> _refreshSession(
    AuthenticationSession currentSession,
  ) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        'api/v1/auth/refresh',
        data: {'refreshToken': currentSession.tokens.refreshToken},
        skipAuthorization: true,
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Token yenileme cevabı boş olamaz.');
      }

      final refreshedSession = AuthenticationSession.fromJson(data);
      await _sessionStore.saveSession(refreshedSession);
      return refreshedSession;
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.unauthenticated ||
          error.kind == ApiErrorKind.forbidden ||
          error.kind == ApiErrorKind.validation) {
        await _sessionStore.clear();
        return null;
      }
      rethrow;
    } on FormatException {
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message:
            'Sunucunun token yenileme cevabı geçersiz. Lütfen yöneticinize bildirin.',
      );
    }
  }
}
