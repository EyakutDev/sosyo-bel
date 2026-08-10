import 'package:flutter/foundation.dart';

/// API adresini build ortamından okur ve platforma göre güvenli yerel varsayılan sağlar.
///
/// Gerçek cihaz veya şirket ortamında adres şu şekilde verilmelidir:
/// --dart-define=SOSYOBEL_API_BASE_URL=https://api.example.com
class ApiConfiguration {
  ApiConfiguration._({
    required this.baseUri,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.sendTimeout,
  });

  static const environmentKey = 'SOSYOBEL_API_BASE_URL';

  final Uri baseUri;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  String get baseUrl => baseUri.toString();

  factory ApiConfiguration.fromEnvironment({
    TargetPlatform? platform,
    String? configuredBaseUrl,
    bool? requireHttps,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 30),
    Duration sendTimeout = const Duration(seconds: 30),
  }) {
    const buildTimeBaseUrl = String.fromEnvironment(environmentKey);
    final explicitBaseUrl = configuredBaseUrl ?? buildTimeBaseUrl;
    final selectedPlatform = platform ?? defaultTargetPlatform;
    final mustUseHttps = requireHttps ?? kReleaseMode;

    final rawBaseUrl = explicitBaseUrl.trim().isNotEmpty
        ? explicitBaseUrl.trim()
        : _localBaseUrl(selectedPlatform);
    final parsedUri = Uri.tryParse(rawBaseUrl);

    if (parsedUri == null ||
        !parsedUri.isAbsolute ||
        parsedUri.host.isEmpty ||
        (parsedUri.scheme != 'http' && parsedUri.scheme != 'https') ||
        parsedUri.hasQuery ||
        parsedUri.hasFragment ||
        parsedUri.userInfo.isNotEmpty) {
      throw const FormatException(
        'SOSYOBEL_API_BASE_URL geçerli bir HTTP(S) sunucu adresi olmalıdır.',
      );
    }

    if (mustUseHttps && parsedUri.scheme != 'https') {
      throw const FormatException(
        'Release derlemelerinde SOSYOBEL_API_BASE_URL HTTPS kullanmalıdır.',
      );
    }

    // Sondaki eğik çizgi, IIS sanal dizini içeren adreslerde göreli endpoint
    // yollarının doğru birleştirilmesini sağlar.
    final normalizedPath = parsedUri.path.endsWith('/')
        ? parsedUri.path
        : '${parsedUri.path}/';

    return ApiConfiguration._(
      baseUri: parsedUri.replace(path: normalizedPath),
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
    );
  }

  static String _localBaseUrl(TargetPlatform platform) {
    // Android emülatöründe 10.0.2.2 geliştirme bilgisayarının localhost adresidir.
    if (platform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }

    return 'http://localhost:5000';
  }
}
