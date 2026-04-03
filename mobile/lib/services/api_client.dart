import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

const _tokenKey = 'medstudy_token';

class ApiClient {
  ApiClient() : dio = Dio(BaseOptions(baseUrl: AppConfig.apiPrefix)) {
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

  Future<List<dynamic>> fetchTopics() async {
    final r = await dio.get('/topics');
    return (r.data['topics'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> fetchTopic(String slug) async {
    final r = await dio.get('/topics/$slug');
    return Map<String, dynamic>.from(r.data['topic'] as Map);
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

  Future<Uint8List> downloadBytes(String absoluteUrl) async {
    final r = await Dio().get<List<int>>(
      absoluteUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(r.data ?? []);
  }
}
