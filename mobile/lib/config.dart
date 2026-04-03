/// Base URL of the Express API **without** trailing slash and **without** `/api`.
/// [apiPrefix] appends `/api` for Dio.
///
/// Default points at production (Render). Override for local API:
/// `flutter run --dart-define=API_BASE=http://10.0.2.2:5000`
///
/// If you mistakenly pass `https://host.com/api`, the `/api` suffix is stripped so
/// requests still hit `https://host.com/api/packages` (not `.../api/api/packages`).
///
/// Extra console logging (topic URLs, PDF download URL, audio URL):
/// `flutter run --dart-define=VERBOSE_LOGS=true`
class AppConfig {
  static const String _apiBaseRaw = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://medical-rgb5.onrender.com',
  );

  static const String _defaultBase = 'https://medical-rgb5.onrender.com';

  /// Normalized host only (no trailing `/`, no `/api` suffix).
  static String get apiBase {
    var s = _apiBaseRaw.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.toLowerCase().endsWith('/api')) {
      s = s.substring(0, s.length - 4);
      while (s.endsWith('/')) {
        s = s.substring(0, s.length - 1);
      }
    }
    if (s.isEmpty) return _defaultBase;
    return s;
  }

  /// When true, prints media URLs and API traces (see [medstudyLog]).
  static const bool verboseLogs = bool.fromEnvironment('VERBOSE_LOGS', defaultValue: false);

  static String get apiPrefix => '$apiBase/api';
}
