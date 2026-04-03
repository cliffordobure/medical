/// Base URL of the Express API **without** trailing slash.
///
/// Default points at production (Render). Override for local API:
/// `flutter run --dart-define=API_BASE=http://10.0.2.2:5000`
class AppConfig {
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://medical-rgb5.onrender.com',
  );

  static String get apiPrefix => '$apiBase/api';
}
