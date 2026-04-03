import 'dart:io';

import '../config.dart';

/// If the API still returns `localhost`, map it for the Android emulator (local API only).
String resolveHostUrl(String url) {
  if (!Platform.isAndroid) return url;
  return url.replaceAll('http://localhost:', 'http://10.0.2.2:').replaceAll('http://127.0.0.1:', 'http://10.0.2.2:');
}

/// Media URLs from [Topic.toDetailJSON]: fix server misconfiguration and emulator localhost.
///
/// If the API is public (e.g. Render) but `pdfUrl`/`audioUrl` still use `localhost`, the Android
/// emulator would otherwise rewrite them to `10.0.2.2` (your PC) — not the real host — and
/// audio/PDF fail with **Connection aborted**. This swaps in [AppConfig.apiBase]'s host first.
String? resolveMediaUrl(String? url) {
  if (url == null || url.isEmpty) return url;
  final u = Uri.tryParse(url);
  if (u == null || !u.hasScheme || !u.hasAuthority) return url;
  final api = Uri.parse(AppConfig.apiBase);
  final mediaLocal = u.host == 'localhost' || u.host == '127.0.0.1';
  final apiRemote = api.host != 'localhost' && api.host != '127.0.0.1';
  if (mediaLocal && apiRemote) {
    // Use resolve so we do not keep localhost's :5000 on the production host.
    var ref = u.path;
    if (u.hasQuery) ref += '?${u.query}';
    if (u.hasFragment) ref += '#${u.fragment}';
    return api.resolve(ref).toString();
  }
  return resolveHostUrl(url);
}
