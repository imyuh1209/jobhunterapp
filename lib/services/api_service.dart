import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/auth_response.dart';
import '../models/job.dart';
import '../models/rest_response.dart';
import '../models/saved_job.dart';
import '../models/resume.dart';
import 'dart:typed_data';
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

  // Upload CV từ bytes (web-friendly). Trả về fileName.
  Future<String> uploadCvBytes(Uint8List bytes, String filename, {String folder = 'resumes'}) async {
    final client = await _clientFuture;
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        'folder': folder,
      });
      final res = await client.dio.post('/api/v1/files', data: form);
      final data = (res.data is Map<String, dynamic>) ? (res.data['data'] ?? res.data) : res.data;
      if (data is Map<String, dynamic>) {
        final fileName = data['fileName'] ?? data['filename'] ?? data['name'];
        return fileName?.toString() ?? '';
      }
      return '';
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception('Upload CV thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}');
    }
  }

  String buildResumeUrl(String fileName, {String folder = 'resumes'}) {
    if (fileName.isEmpty) return '';
    return '/storage/$folder/$fileName';
  }

  Future<Map<String, dynamic>> _getAccountSafe() async {
    final acc = await getAccount();
    return acc;
  }

  Future<bool> hasAppliedJob(String jobId) async {
    try {
      final acc = await _getAccountSafe();
      final uidRaw = acc['id'] ?? acc['userId'] ?? (acc['user'] is Map ? acc['user']['id'] : null);
      int? uid = uidRaw is int ? uidRaw : int.tryParse(uidRaw?.toString() ?? '');
      if (uid == null) return false;
      return await hasAppliedJobByUser(jobId, uid);
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasAppliedJobByUser(String jobId, int userId) async {
    final client = await _clientFuture;
    try {
      final filter = Uri.encodeQueryComponent('user.id==$userId and job.id==$jobId');
      final res = await client.dio.get(
        '/api/v1/resumes',
        queryParameters: {
          'filter': filter,
          'page': 1,
          'size': 1,
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final meta = extractMeta(res.data);
      final total = meta?['total'];
      if (total is int) return total > 0;
      final list = unwrapPageList(res.data);
      return list.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> applyResumeForJob({required String jobId, String? url, String status = 'PENDING', String? email}) async {
    final client = await _clientFuture;
    try {
      final acc = await _getAccountSafe();
      final uidRaw = acc['id'] ?? acc['userId'] ?? (acc['user'] is Map ? acc['user']['id'] : null);
      int? uid = uidRaw is int ? uidRaw : int.tryParse(uidRaw?.toString() ?? '');
      final mail = email ?? acc['email']?.toString();
      if (uid == null) throw Exception('Không tìm thấy user.id để ứng tuyển');
      // Chặn trùng
      final existed = await hasAppliedJobByUser(jobId, uid);
      if (existed) {
        throw Exception('Bạn đã ứng tuyển công việc này');
      }
      final payload = {
        'email': mail,
        if (url != null && url.isNotEmpty) 'url': url,
        'status': status,
        'user': {'id': uid},
        'job': {'id': jobId},
      };
      await client.dio.post(
        '/api/v1/resumes',
        data: payload,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return true;
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception('Ứng tuyển thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}');
    }
  }

  Future<List<Resume>> getMyResumes({int page = 1, int pageSize = 10}) async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.post(
        '/api/v1/resumes/by-user',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return parsePageList<Resume>(res.data, (m) => Resume.fromJson(m));
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception('Tải hồ sơ của tôi thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}');
    }
  }

  Future<int> countResumesByJob(String jobId) async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get(
        '/api/v1/resumes/count-by-job/$jobId',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final v = data['data'] ?? data['count'] ?? data['total'];
        if (v is int) return v;
        final parsed = int.tryParse(v?.toString() ?? '');
        return parsed ?? 0;
      }
      if (data is int) return data;
      final parsed = int.tryParse(data?.toString() ?? '');
      return parsed ?? 0;
    } catch (_) {
      return 0;
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