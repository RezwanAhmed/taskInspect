/// Settings that differ per environment, fixed when the app is built:
///
/// ```
/// flutter run --dart-define-from-file=config/dev.json
/// flutter build appbundle --dart-define-from-file=config/prod.json
/// ```
///
/// Without a file the app uses the development defaults, which reach a
/// backend on the developer's computer from the Android emulator.
class AppConfig {
  AppConfig({required this.environment, required this.apiBaseUrl}) {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw ArgumentError.value(apiBaseUrl, 'apiBaseUrl', 'must be an http(s) URL');
    }
    if (environment != AppEnvironment.dev && !uri.isScheme('https')) {
      throw ArgumentError.value(apiBaseUrl, 'apiBaseUrl', 'must use https outside development');
    }
  }

  /// Reads `APP_ENV` and `API_BASE_URL` from the build (`--dart-define`).
  factory AppConfig.fromEnvironment() {
    return AppConfig(
      environment: AppEnvironment.parse(const String.fromEnvironment('APP_ENV', defaultValue: 'dev')),
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: defaultDevApiBaseUrl),
    );
  }

  /// The Android emulator reaches the host computer at 10.0.2.2.
  static const defaultDevApiBaseUrl = 'http://10.0.2.2:8080';

  final AppEnvironment environment;

  /// Base URL of the backend API, without a trailing slash.
  final String apiBaseUrl;

  bool get isProduction => environment == AppEnvironment.prod;
}

enum AppEnvironment {
  dev,
  staging,
  prod;

  static AppEnvironment parse(String value) {
    return AppEnvironment.values.firstWhere(
      (environment) => environment.name == value,
      orElse: () => throw ArgumentError.value(value, 'APP_ENV', 'must be dev, staging or prod'),
    );
  }
}
