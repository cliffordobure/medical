import 'package:flutter/foundation.dart';

import '../config.dart';

/// Debug/profile: always logs in debug mode. Release: set `--dart-define=VERBOSE_LOGS=true`.
void medstudyLog(String message) {
  if (kDebugMode || AppConfig.verboseLogs) {
    debugPrint('[medstudy] $message');
  }
}

/// Use for failures you need to see even when chasing production issues (still no-op in release unless VERBOSE_LOGS).
void medstudyLogError(String message, [Object? err, StackTrace? st]) {
  debugPrint('[medstudy] ERROR: $message');
  if (err != null) debugPrint('[medstudy] $err');
  if (st != null && (kDebugMode || AppConfig.verboseLogs)) debugPrint('$st');
}
