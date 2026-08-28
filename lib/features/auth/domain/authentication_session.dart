import 'package:sosyo_bel/core/auth/auth_tokens.dart';

/// Başarılı girişten dönen kullanıcı ve belediye kapsamını temsil eder.
class AuthenticationSession {
  const AuthenticationSession({required this.tokens, required this.user});

  final AuthTokens tokens;
  final AuthenticatedUser user;

  factory AuthenticationSession.fromJson(Map<String, dynamic> json) {
    final userJson = _readMap(json['user'], fieldName: 'user');
    return AuthenticationSession(
      tokens: AuthTokens.fromJson(json),
      user: AuthenticatedUser.fromJson(userJson),
    );
  }

  Map<String, dynamic> toJson() => {...tokens.toJson(), 'user': user.toJson()};

  AuthenticationSession copyWith({AuthTokens? tokens}) =>
      AuthenticationSession(tokens: tokens ?? this.tokens, user: user);
}

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.roles,
    this.email,
  });

  final String userId;
  final String username;
  final String? email;
  final String displayName;
  final List<String> roles;

  factory AuthenticatedUser.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    if (rawRoles is! List) {
      throw const FormatException('Kullanıcı rol bilgisi geçersiz.');
    }

    final roles = rawRoles
        .whereType<String>()
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .toList(growable: false);
    return AuthenticatedUser(
      userId: _readRequiredString(json, 'userId'),
      username: _readRequiredString(json, 'username'),
      email: _readOptionalString(json, 'email'),
      displayName: _readRequiredString(json, 'displayName'),
      roles: List.unmodifiable(roles),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'username': username,
    'email': email,
    'displayName': displayName,
    'roles': roles,
  };
}

Map<String, dynamic> _readMap(Object? value, {required String fieldName}) {
  if (value is! Map) {
    throw FormatException('$fieldName alanı geçersiz.');
  }

  return value.map((key, dynamic item) => MapEntry(key.toString(), item));
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key alanı eksik veya geçersiz.');
  }

  return value.trim();
}

String? _readOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('$key alanı geçersiz.');
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
