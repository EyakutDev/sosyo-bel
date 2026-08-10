import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosyo_bel/core/config/api_configuration.dart';

void main() {
  group('ApiConfiguration', () {
    test('Android emülatörü için bilgisayarın localhost adresini kullanır', () {
      final configuration = ApiConfiguration.fromEnvironment(
        platform: TargetPlatform.android,
        requireHttps: false,
      );

      expect(configuration.baseUrl, 'http://10.0.2.2:5000/');
    });

    test('iOS simülatörü için localhost adresini kullanır', () {
      final configuration = ApiConfiguration.fromEnvironment(
        platform: TargetPlatform.iOS,
        requireHttps: false,
      );

      expect(configuration.baseUrl, 'http://localhost:5000/');
    });

    test('IIS sanal dizinini korur ve sona slash ekler', () {
      final configuration = ApiConfiguration.fromEnvironment(
        platform: TargetPlatform.android,
        configuredBaseUrl: 'https://api.catsyazilim.com/sosyo-bel',
        requireHttps: true,
      );

      expect(configuration.baseUrl, 'https://api.catsyazilim.com/sosyo-bel/');
    });

    test('release benzeri ortamda HTTP adresini reddeder', () {
      expect(
        () => ApiConfiguration.fromEnvironment(
          platform: TargetPlatform.android,
          configuredBaseUrl: 'http://api.example.com',
          requireHttps: true,
        ),
        throwsFormatException,
      );
    });

    test('query içeren sunucu adresini reddeder', () {
      expect(
        () => ApiConfiguration.fromEnvironment(
          platform: TargetPlatform.android,
          configuredBaseUrl: 'https://api.example.com?tenant=test',
          requireHttps: true,
        ),
        throwsFormatException,
      );
    });
  });
}
