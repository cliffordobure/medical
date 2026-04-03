import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../util/app_log.dart';

const _tokenKey = 'medstudy_token';

BaseOptions _baseOptions() {
  return BaseOptions(
    baseUrl: AppConfig.apiPrefix,
    // Render free tier cold start often needs 30–90s before accepting connections
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 45),
    sendTimeout: const Duration(seconds: 45),
    headers: {'Accept': 'application/json'},
  );
}

class ApiClient {
  ApiClient() : dio = Dio(_baseOptions()) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final t = await getToken();
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;

  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_tokenKey);
  }

  static Future<void> saveToken(String? token) async {
    final p = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await p.remove(_tokenKey);
    } else {
      await p.setString(_tokenKey, token);
    }
  }

  /// User-facing hint when requests fail (same base as [AppConfig.apiBase]).
  static String connectionHint(Object? error) {
    final base = AppConfig.apiBase;
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Timed out reaching $base. Is the server running and port open?';
        case DioExceptionType.connectionError:
          return 'Cannot reach $base.\n'
              '• Emulator: host should be 10.0.2.2 (default).\n'
              '• Real phone: use your computer\'s Wi‑Fi IP, e.g.\n'
              '  flutter run --dart-define=API_BASE=http://192.168.x.x:5000';
        case DioExceptionType.badResponse:
          return 'Server error (${error.response?.statusCode ?? '?'}).';
        default:
          break;
      }
    }
    return 'Could not load data. API: $base';
  }

  Future<List<dynamic>> fetchTopics() async {
    final r = await dio.get('/topics');
    return (r.data['topics'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> fetchTopic(String slug) async {
    medstudyLog('GET /api/topics/$slug …');
    try {
      final r = await dio.get('/topics/$slug');
      final raw = r.data['topic'];
      final topic = Map<String, dynamic>.from(raw as Map);
      medstudyLog(
        'topic ok: title=${topic['title']} pdfUrl=${topic['pdfUrl']} audioUrl=${topic['audioUrl']}',
      );
      return topic;
    } catch (e, st) {
      medstudyLogError('fetchTopic("$slug")', e, st);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await dio.post('/auth/login', data: {'email': email, 'password': password});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> register(String email, String password) async {
    final r = await dio.post('/auth/register', data: {'email': email, 'password': password});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> me() async {
    final r = await dio.get('/auth/me');
    return Map<String, dynamic>.from(r.data['user'] as Map);
  }

  Future<Map<String, dynamic>> fetchPackages() async {
    final r = await dio.get('/packages');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> initializePayment(String packageId) async {
    final r = await dio.post('/payments/initialize', data: {'packageId': packageId});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> verifyPayment(String reference) async {
    final r = await dio.get('/payments/verify/${Uri.encodeComponent(reference)}');
    return Map<String, dynamic>.from(r.data as Map);
  }

  /// Wakes a sleeping host (e.g. Render) with a tiny request before a large PDF download.
  static Future<void> pokeHealthEndpoint() async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/health');
    medstudyLog('GET $uri (wake server)');
    final d = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 150),
        receiveTimeout: const Duration(seconds: 90),
        responseType: ResponseType.json,
      ),
    );
    try {
      await d.getUri(uri).timeout(const Duration(seconds: 180));
      medstudyLog('health ok');
    } catch (e) {
      medstudyLog('health wake failed (continuing): $e');
    }
  }

  /// [onProgress] receives (bytesReceived, totalBytesOrNull).
  ///
  /// Uses a hard wall-clock timeout so we never hang forever if the server never sends body bytes
  /// (Dio `receiveTimeout` alone may not fire until the first chunk).
  Future<Uint8List> downloadBytes(
    String absoluteUrl, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final d = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 150),
        receiveTimeout: const Duration(seconds: 90),
        responseType: ResponseType.bytes,
      ),
    );

    medstudyLog('downloadBytes: $absoluteUrl');
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        medstudyLog('downloadBytes retry #$attempt');
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
      }
      try {
        final r = await d
            .get<List<int>>(
              absoluteUrl,
              onReceiveProgress: (c, t) {
                final total = t == -1 ? null : t;
                onProgress?.call(c, total);
              },
            )
            .timeout(
              const Duration(minutes: 15),
              onTimeout: () => throw TimeoutException(
                'PDF download exceeded 15 minutes',
                const Duration(minutes: 15),
              ),
            );
        medstudyLog('downloadBytes done: ${r.data?.length ?? 0} bytes');
        return Uint8List.fromList(r.data ?? []);
      } on TimeoutException {
        medstudyLogError('downloadBytes timeout', absoluteUrl);
        rethrow;
      } on DioException catch (e) {
        medstudyLogError(
          'downloadBytes Dio ${e.response?.statusCode} ${e.type}',
          e.message,
        );
        final retry = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;
        if (!retry || attempt == 2) rethrow;
      }
    }
    throw StateError('downloadBytes: unreachable');
  }
}
