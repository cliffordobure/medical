/// Base URL of the Express API **without** trailing slash.
///
/// - Android emulator: `http://10.0.2.2:5000` reaches host machine localhost.
/// - Physical device: use your PC LAN IP, e.g. `http://192.168.1.10:5000`.
/// - Set at build time: `flutter run --dart-define=API_BASE=http://192.168.x.x:5000`
class AppConfig {
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://10.0.2.2:5000',
  );

  static String get apiPrefix => '$apiBase/api';
}
