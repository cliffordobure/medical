/// Base URL of the Express API **without** trailing slash.
///
/// Default points at production (Render). Override for local API:
/// `flutter run --dart-define=API_BASE=http://10.0.2.2:5000`
///
/// Extra console logging (topic URLs, PDF download URL, audio URL):
/// `flutter run --dart-define=VERBOSE_LOGS=true`
class AppConfig {
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://medical-rgb5.onrender.com',
  );

  /// When true, prints media URLs and API traces (see [medstudyLog]).
  static const bool verboseLogs = bool.fromEnvironment('VERBOSE_LOGS', defaultValue: false);

  static String get apiPrefix => '$apiBase/api';
}
