import 'package:dio/dio.dart';
import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dio_adapter_stub.dart' if (dart.library.html) 'dio_adapter_web.dart';
import 'package:flutter/material.dart';

class ApiClient {
  final Dio dio;
  final FlutterSecureStorage secureStorage;
  final CookieJar? cookieJar;
  static Completer<bool>? _refreshingCompleter;

  ApiClient._(this.dio, this.secureStorage, this.cookieJar);

  static Future<ApiClient> create({required String baseUrl}) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    // Web: gửi kèm cookies
    final adapter = buildAdapterWithCredentials();
    if (adapter != null) {
      dio.httpClientAdapter = adapter;
    }

    // Cookie Jar (runtime) cho mobile nếu cần
    CookieJar? jar;
    if (!kIsWeb) {
      jar = CookieJar();
      dio.interceptors.add(CookieManager(jar));
    }

    const storage = FlutterSecureStorage();

    // Interceptor: gắn Authorization và xử lý 401 -> refresh (hàng đợi) -> retry
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = await storage.read(key: 'accessToken');
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          handler.next(options);
        },
        onError: (DioException err, handler) async {
          // 403: không có quyền
          if (err.response?.statusCode == 403) {
            debugPrint('403 Forbidden: Không có quyền truy cập');
            return handler.next(err);
          }
          // 401: cần refresh token
          if (err.response?.statusCode == 401) {
            // Khởi tạo hàng đợi refresh: các request sau await cùng một completer
            if (_refreshingCompleter == null) {
              _refreshingCompleter = Completer<bool>();
              _handleRefresh(dio, storage).then((ok) async {
                _refreshingCompleter?.complete(ok);
                _refreshingCompleter = null;
              }).catchError((e) {
                _refreshingCompleter?.complete(false);
                _refreshingCompleter = null;
              });
            }
            final refreshed = await (_refreshingCompleter!.future);
            if (refreshed) {
              final newAccessToken = await storage.read(key: 'accessToken');
              if (newAccessToken != null && newAccessToken.isNotEmpty) {
                err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              }
              try {
                final cloneReq = await dio.fetch(err.requestOptions);
                return handler.resolve(cloneReq);
              } catch (_) {}
            }
          }
          handler.next(err);
        },
      ),
    );

    return ApiClient._(dio, storage, jar);
  }

  // Login
  Future<Map<String, dynamic>> login({required String username, required String password}) async {
    final res = await dio.post('/api/v1/auth/login', data: {
      'username': username,
      'password': password,
    });
    final data = (res.data is Map<String, dynamic>) ? (res.data['data'] ?? res.data) : res.data;
    if (data is Map<String, dynamic>) {
      final accessToken = data['access_token'] ?? data['accessToken'] ?? data['token'];
      final refreshToken = data['refresh_token'] ?? data['refreshToken'];
      if (accessToken is String) {
        await secureStorage.write(key: 'accessToken', value: accessToken);
      }
      if (refreshToken is String) {
        await secureStorage.write(key: 'refreshToken', value: refreshToken);
      }
      return data;
    }
    return {'data': res.data};
  }

  Future<void> logout() async {
    try {
      await dio.post('/api/v1/auth/logout');
    } catch (_) {}
    await secureStorage.delete(key: 'accessToken');
    await secureStorage.delete(key: 'refreshToken');
    await secureStorage.deleteAll();
    await cookieJar?.deleteAll();
  }

  // Refresh chung: web dùng GET với cookie; mobile dùng GET header hoặc POST body
  static Future<bool> _handleRefresh(Dio dio, FlutterSecureStorage storage) async {
    try {
      if (kIsWeb) {
        final res = await dio.get('/api/v1/auth/refresh', options: Options(headers: {'Accept': 'application/json'}));
        final data = (res.data is Map<String, dynamic>) ? (res.data['data'] ?? res.data) : res.data;
        final accessToken = (data is Map<String, dynamic>)
            ? (data['access_token'] ?? data['accessToken'] ?? data['token'])
            : null;
        final refreshToken = (data is Map<String, dynamic>) ? (data['refresh_token'] ?? data['refreshToken']) : null;
        if (accessToken is String) {
          await storage.write(key: 'accessToken', value: accessToken);
        }
        if (refreshToken is String) {
          await storage.write(key: 'refreshToken', value: refreshToken);
        }
        return accessToken is String && accessToken.isNotEmpty;
      } else {
        final saved = await storage.read(key: 'refreshToken');
        if (saved == null || saved.isEmpty) return false;
        // Try GET with header first
        try {
          final res = await dio.get(
            '/api/v1/auth/refresh',
            options: Options(headers: {'X-Refresh-Token': saved, 'Accept': 'application/json'}),
          );
          final data = (res.data is Map<String, dynamic>) ? (res.data['data'] ?? res.data) : res.data;
          final accessToken = (data is Map<String, dynamic>)
              ? (data['access_token'] ?? data['accessToken'] ?? data['token'])
              : null;
          final refreshToken = (data is Map<String, dynamic>) ? (data['refresh_token'] ?? data['refreshToken']) : null;
          if (accessToken is String) {
            await storage.write(key: 'accessToken', value: accessToken);
          }
          if (refreshToken is String) {
            await storage.write(key: 'refreshToken', value: refreshToken);
          }
          return accessToken is String && accessToken.isNotEmpty;
        } catch (e) {
          debugPrint('Refresh by GET failed: $e');
        }
        // Fallback: POST body
        try {
          final res = await dio.post(
            '/api/v1/auth/refresh',
            data: {'refreshToken': saved},
            options: Options(headers: {'Accept': 'application/json'}),
          );
          final data = (res.data is Map<String, dynamic>) ? (res.data['data'] ?? res.data) : res.data;
          final accessToken = (data is Map<String, dynamic>)
              ? (data['access_token'] ?? data['accessToken'] ?? data['token'])
              : null;
          final refreshToken = (data is Map<String, dynamic>) ? (data['refresh_token'] ?? data['refreshToken']) : null;
          if (accessToken is String) {
            await storage.write(key: 'accessToken', value: accessToken);
          }
          if (refreshToken is String) {
            await storage.write(key: 'refreshToken', value: refreshToken);
          }
          return accessToken is String && accessToken.isNotEmpty;
        } catch (e) {
          debugPrint('Refresh by POST failed: $e');
        }
        return false;
      }
    } catch (e) {
      debugPrint('Handle refresh error: $e');
      return false;
    }
  }
}