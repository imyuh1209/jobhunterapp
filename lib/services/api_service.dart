import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/auth_response.dart';
import '../models/job.dart';
import '../models/rest_response.dart';
import '../models/saved_job.dart';
import 'dio_client.dart';

class ApiService {
  ApiService() {
    _clientFuture = ApiClient.create(baseUrl: ApiConfig.baseUrl);
  }

  late final Future<ApiClient> _clientFuture;

  Future<AuthResponse> login({required String email, required String password}) async {
    final client = await _clientFuture;
    debugPrint('POST /api/v1/auth/login payload: {"username":"$email","password":"******"}');
    try {
      final data = await client.login(username: email, password: password);
      final token = data['access_token'] ?? data['accessToken'] ?? data['token'];
      return AuthResponse(token: token?.toString() ?? '');
    } on DioException catch (e) {
      final message = _extractMessage(e.response?.data);
      throw Exception('Đăng nhập thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}');
    }
  }

  Future<void> register({required String email, required String password, String? name}) async {
    final client = await _clientFuture;
    try {
      await client.dio.post('/api/v1/auth/register', data: {
        'email': email,
        'username': email,
        'password': password,
        if (name != null) 'name': name,
      });
    } on DioException catch (e) {
      final message = _extractMessage(e.response?.data);
      throw Exception('Đăng ký thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}');
    }
  }

  Future<Map<String, dynamic>> getAccount() async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get('/api/v1/auth/account', options: Options(headers: {'Accept': 'application/json'}));
      final data = (res.data is Map<String, dynamic>) ? (res.data['data'] ?? res.data) : res.data;
      return (data is Map<String, dynamic>) ? data : {'data': data};
    } on DioException catch (e) {
      final message = _extractMessage(e.response?.data);
      throw Exception('Lấy thông tin tài khoản thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}');
    }
  }

  Future<void> logout() async {
    final client = await _clientFuture;
    await client.logout();
  }

  Future<List<Job>> getJobs({String? category, int page = 1, int pageSize = 10}) async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get(
        '/api/v1/jobs',
        queryParameters: {
          // spring.data.web.pageable.one-indexed-parameters=true -> page bắt đầu từ 1
          'page': page,
          'pageSize': pageSize,
          if (category != null && category.isNotEmpty) 'category': category,
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return parsePageList<Job>(res.data, (m) => Job.fromJson(m));
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception('Tải danh sách việc thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}');
    }
  }

  Future<Job> getJob(String id) async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get('/api/v1/jobs/$id', options: Options(headers: {'Accept': 'application/json'}));
      final data = res.data;
      Map<String, dynamic> map = {};
      if (data is Map<String, dynamic>) {
        map = (data['data'] is Map<String, dynamic>) ? data['data'] as Map<String, dynamic> : data;
      }
      return Job.fromJson(map);
    } on DioException catch (e) {
      final message = _extractMessage(e.response?.data);
      throw Exception('Tải chi tiết việc thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}');
    }
  }

  // Saved Jobs
  Future<List<SavedJob>> getSavedJobs() async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get('/api/v1/saved-jobs', options: Options(headers: {'Accept': 'application/json'}));
      return parseList<SavedJob>(res.data, (m) => SavedJob.fromJson(m));
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception('Tải danh sách đã lưu thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}');
    }
  }

  Future<bool> saveJob(String jobId) async {
    final client = await _clientFuture;
    try {
      await client.dio.post('/api/v1/saved-jobs', queryParameters: {'jobId': jobId});
      return true;
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception('Lưu job thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}');
    }
  }

  Future<bool> unsaveBySavedId(String savedId) async {
    final client = await _clientFuture;
    try {
      await client.dio.delete('/api/v1/saved-jobs/$savedId');
      return true;
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception('Bỏ lưu job thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}');
    }
  }

  Future<bool> unsaveByJobId(String jobId) async {
    final client = await _clientFuture;
    try {
      await client.dio.delete('/api/v1/saved-jobs/$jobId', queryParameters: {'byJobId': true});
      return true;
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception('Bỏ lưu job thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}');
    }
  }

  Future<bool> isJobSaved(String jobId) async {
    try {
      final list = await getSavedJobs();
      return list.any((e) => e.jobId == jobId);
    } catch (_) {
      return false;
    }
  }

  String _extractMessage(dynamic body) {
    try {
      if (body is Map<String, dynamic>) {
        final m = body['message'] ?? body['error'];
        return m?.toString() ?? '';
      }
      return body?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }
}