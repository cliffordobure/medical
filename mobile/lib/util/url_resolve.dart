import 'dart:io';

/// If the API still returns `localhost`, map it for the Android emulator.
String resolveHostUrl(String url) {
  if (!Platform.isAndroid) return url;
  return url.replaceAll('http://localhost:', 'http://10.0.2.2:').replaceAll('http://127.0.0.1:', 'http://10.0.2.2:');
}
