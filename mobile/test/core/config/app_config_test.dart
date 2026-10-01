import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/di/injection.dart';

void main() {
  test('without build settings the app uses the development backend', () {
    final config = AppConfig.fromEnvironment();

    expect(config.environment, AppEnvironment.dev);
    expect(config.apiBaseUrl, AppConfig.defaultDevApiBaseUrl);
    expect(config.isProduction, isFalse);
  });

  test('production must use https', () {
    expect(
      () => AppConfig(environment: AppEnvironment.prod, apiBaseUrl: 'http://api.example.com'),
      throwsArgumentError,
    );
    expect(
      AppConfig(environment: AppEnvironment.prod, apiBaseUrl: 'https://api.example.com').isProduction,
      isTrue,
    );
  });

  test('invalid URLs and environments are refused', () {
    expect(() => AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'not a url'), throwsArgumentError);
    expect(() => AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'ftp://host'), throwsArgumentError);
    expect(() => AppEnvironment.parse('test'), throwsArgumentError);
    expect(AppEnvironment.parse('staging'), AppEnvironment.staging);
  });

  test('config is available from the service locator', () async {
    await configureDependencies();

    expect(getIt<AppConfig>().environment, AppEnvironment.dev);
  });
}
