import 'package:dio/dio.dart';
import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
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

    // LogInterceptor chỉ bật ở debug để quan sát headers/body (đã che sensitive)
    if (!kReleaseMode) {
      dio.interceptors.add(LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: false,
      ));
    }

    // Interceptor: gắn Authorization và xử lý 401 -> refresh (hàng đợi) -> retry
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = await storage.read(key: 'accessToken');
          // Cho phép bỏ qua Authorization trên một số request (ví dụ refresh)
          final skipAuth = options.extra['skipAuth'] == true;
          // Xóa header Authorization ở cấp client nếu tồn tại để tránh rò rỉ sang request skipAuth
          try {
            dio.options.headers.remove('Authorization');
          } catch (_) {}
          if (!skipAuth && accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          } else {
            // Đảm bảo không có Authorization trên request mở
            try {
              options.headers.remove('Authorization');
            } catch (_) {}
          }
          // Logging an toàn khi debug: ẩn mật khẩu và token
          if (!kReleaseMode) {
            try {
              final method = options.method;
              final path = options.path;
              dynamic data = options.data;
              if (data is Map<String, dynamic>) {
                final copy = Map<String, dynamic>.from(data);
                if (copy.containsKey('password')) copy['password'] = '******';
                if (copy.containsKey('currentPassword')) copy['currentPassword'] = '******';
                if (copy.containsKey('newPassword')) copy['newPassword'] = '******';
                if (copy.containsKey('access_token')) copy['access_token'] = '***';
                if (copy.containsKey('token')) copy['token'] = '***';
                data = copy;
              }
              debugPrint('[REQ] '+method+' '+path+' skipAuth='+skipAuth.toString()+' body='+ (data is Map ? data.toString() : (data?.toString() ?? '')));
            } catch (_) {}
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (!kReleaseMode) {
            try {
              debugPrint('[RES] '+response.requestOptions.method+' '+response.requestOptions.path+' -> '+(response.statusCode?.toString() ?? ''));
            } catch (_) {}
          }
          handler.next(response);
        },
        onError: (DioException err, handler) async {
          // Tôn trọng skipAuth: không refresh/không gắn Authorization cho request "mở"
          final skipAuth = err.requestOptions.extra['skipAuth'] == true;
          if (skipAuth) {
            return handler.next(err);
          }
          // 403: không có quyền
          if (err.response?.statusCode == 403) {
            debugPrint('403 Forbidden: Không có quyền truy cập');
            return handler.next(err);
          }
          // 401 hoặc một số 400 đặc thù: cần refresh token
          final isUnauthorized = err.response?.statusCode == 401;
          final isUsersMeBadRequest = (err.response?.statusCode == 400) &&
              (err.requestOptions.path.contains('/api/v1/users/me'));
          if (isUnauthorized || isUsersMeBadRequest) {
            // Tránh lặp vô hạn: nếu đã retry một lần, không refresh nữa
            if (err.requestOptions.extra['retry'] == true) {
              return handler.next(err);
            }
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
              if (!skipAuth && newAccessToken != null && newAccessToken.isNotEmpty) {
                err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              }
              try {
                // Đánh dấu retry để ngăn vòng lặp 401->refresh vô hạn
                err.requestOptions.extra['retry'] = true;
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
  Future<Map<String, dynamic>> login({required String username, required String password, bool remember = true}) async {
    final res = await dio.post(
      '/api/v1/auth/login',
      data: {
        'username': username,
        'password': password,
      },
      options: Options(
        headers: {'Accept': 'application/json'},
        extra: {'skipAuth': true},
      ),
    );
    final data = (res.data is Map<String, dynamic>) ? (res.data['data'] ?? res.data) : res.data;
    if (data is Map<String, dynamic>) {
      final accessToken = data['access_token'] ?? data['accessToken'] ?? data['token'];
      final refreshToken = data['refresh_token'] ?? data['refreshToken'];
      if (accessToken is String) {
        await secureStorage.write(key: 'accessToken', value: accessToken);
      }
      // Chỉ lưu refresh token khi bật "ghi nhớ đăng nhập"
      if (remember && refreshToken is String) {
        await secureStorage.write(key: 'refreshToken', value: refreshToken);
      } else {
        // Xoá refresh token cũ nếu có để tránh kéo dài phiên
        await secureStorage.delete(key: 'refreshToken');
      }
      await secureStorage.write(key: 'rememberMe', value: remember ? 'true' : 'false');
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
        final saved = await storage.read(key: 'refreshToken');
        final res = await dio.get(
          '/api/v1/auth/refresh',
          options: Options(
            headers: {
              'Accept': 'application/json',
              if (saved != null && saved.isNotEmpty) 'X-Refresh-Token': saved,
            },
            extra: {'skipAuth': true},
          ),
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
      } else {
        final saved = await storage.read(key: 'refreshToken');
        if (saved == null || saved.isEmpty) return false;
        // Try GET with header first
        try {
          final res = await dio.get(
            '/api/v1/auth/refresh',
            options: Options(headers: {'X-Refresh-Token': saved, 'Accept': 'application/json'}, extra: {'skipAuth': true}),
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
            options: Options(headers: {'Accept': 'application/json'}, extra: {'skipAuth': true}),
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