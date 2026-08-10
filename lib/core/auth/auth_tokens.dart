/// API tarafından üretilen oturum anahtarlarını ve sürelerini birlikte tutar.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.accessTokenExpiresAtUtc,
    required this.refreshToken,
    required this.refreshTokenExpiresAtUtc,
  });

  final String accessToken;
  final DateTime accessTokenExpiresAtUtc;
  final String refreshToken;
  final DateTime refreshTokenExpiresAtUtc;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final accessExpiry = DateTime.tryParse(
      json['accessTokenExpiresAtUtc']?.toString() ?? '',
    );
    final refreshExpiry = DateTime.tryParse(
      json['refreshTokenExpiresAtUtc']?.toString() ?? '',
    );

    if (accessToken is! String ||
        accessToken.trim().isEmpty ||
        refreshToken is! String ||
        refreshToken.trim().isEmpty ||
        accessExpiry == null ||
        refreshExpiry == null) {
      throw const FormatException('Oturum token verisi eksik veya geçersiz.');
    }

    return AuthTokens(
      accessToken: accessToken,
      accessTokenExpiresAtUtc: accessExpiry.toUtc(),
      refreshToken: refreshToken,
      refreshTokenExpiresAtUtc: refreshExpiry.toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'accessTokenExpiresAtUtc': accessTokenExpiresAtUtc
        .toUtc()
        .toIso8601String(),
    'refreshToken': refreshToken,
    'refreshTokenExpiresAtUtc': refreshTokenExpiresAtUtc
        .toUtc()
        .toIso8601String(),
  };

  bool isAccessTokenExpired(DateTime nowUtc) =>
      !accessTokenExpiresAtUtc.isAfter(nowUtc.toUtc());

  bool isRefreshTokenExpired(DateTime nowUtc) =>
      !refreshTokenExpiresAtUtc.isAfter(nowUtc.toUtc());
}
