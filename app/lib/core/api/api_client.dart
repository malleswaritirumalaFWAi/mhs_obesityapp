import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

/// Thin wrapper over Dio with bearer-token injection.
class ApiClient {
  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBase, // resolved at runtime (web vs Android)
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await clearToken();
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  /// Called when any API request returns 401. Set by SessionController.
  void Function()? onUnauthorized;

  static const _tokenKey = 'fq_token';
  final FlutterSecureStorage _storage;
  late final Dio _dio;

  Dio get dio => _dio;

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<Map<String, dynamic>> getJson(String path,
      {Map<String, dynamic>? query}) async {
    final r = await _dio.get(path, queryParameters: query);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> postJson(String path, Object? body) async {
    final r = await _dio.post(path, data: body);
    return Map<String, dynamic>.from((r.data as Map?) ?? {});
  }

  Future<Map<String, dynamic>> putJson(String path, Object? body) async {
    final r = await _dio.put(path, data: body);
    return Map<String, dynamic>.from((r.data as Map?) ?? {});
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final r = await _dio.delete(path);
    return Map<String, dynamic>.from((r.data as Map?) ?? {});
  }
}

final secureStorageProvider = Provider((_) => const FlutterSecureStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(secureStorageProvider));
});
