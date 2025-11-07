import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/auth_response.dart';
import '../models/job.dart';
import '../models/job_detail.dart';
import '../models/company_detail.dart';
import '../models/company_brief.dart';
import '../models/rest_response.dart';
import '../models/saved_job.dart';
import '../models/resume.dart';
import '../models/subscriber.dart';
import '../models/jobs_search_result.dart';
import '../models/home_banner.dart';
import 'dart:typed_data';
import 'dio_client.dart';

class ApiService {
  ApiService() {
    _clientFuture = ApiClient.create(baseUrl: ApiConfig.baseUrl);
  }

  late final Future<ApiClient> _clientFuture;

  Future<AuthResponse> login({
    required String email,
    required String password,
    bool remember = true,
  }) async {
    final client = await _clientFuture;
    debugPrint(
      'POST /api/v1/auth/login payload: {"username":"$email","password":"******"}',
    );
    try {
      final data = await client.login(
        username: email,
        password: password,
        remember: remember,
      );
      final token =
          data['access_token'] ?? data['accessToken'] ?? data['token'];
      return AuthResponse(token: token?.toString() ?? '');
    } on DioException catch (e) {
      final message = _extractMessage(e.response?.data);
      throw Exception(
        'Đăng nhập thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    String? name,
    String? gender,
    String? address,
  }) async {
    final client = await _clientFuture;
    try {
      // Xoá token cũ trước khi đăng ký để tránh gửi nhầm Authorization
      try {
        await client.secureStorage.delete(key: 'accessToken');
        await client.secureStorage.delete(key: 'refreshToken');
      } catch (_) {}

      debugPrint(
        'POST /api/v1/auth/register payload: {"email":"$email","username":"$email","password":"******"${name != null ? ',"name":"$name"' : ''}}',
      );
      await client.dio.post(
        '/api/v1/auth/register',
        data: {
          'email': email,
          'username': email,
          'password': password,
          if (name != null) 'name': name,
          if (gender != null) 'gender': gender,
          if (address != null) 'address': address,
        },
        options: Options(
          headers: {'Accept': 'application/json', 'Authorization': null},
          extra: {'skipAuth': true},
        ),
      );
    } on DioException catch (e) {
      final message = _extractMessage(e.response?.data);
      final status = e.response?.statusCode;
      // Phân biệt rõ 400 (dữ liệu/đăng ký trùng) và 401 (token sai)
      if (status == 400) {
        throw Exception(
          'Đăng ký thất bại: 400 - Dữ liệu không hợp lệ hoặc email đã tồn tại${message.isNotEmpty ? ' - $message' : ''}',
        );
      }
      if (status == 401) {
        throw Exception(
          'Đăng ký thất bại: 401 - Token không hợp lệ (không kèm/đã hết hạn)${message.isNotEmpty ? ' - $message' : ''}',
        );
      }
      throw Exception(
        'Đăng ký thất bại: ${status ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<Map<String, dynamic>> getAccount() async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get(
        '/api/v1/auth/account',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      // Backend hiện trả về dưới root "user". Ưu tiên lấy data['user'] nếu có.
      final raw = res.data;
      Map<String, dynamic> map = {};
      if (raw is Map<String, dynamic>) {
        // Một số backend bọc thêm 'data', ưu tiên 'user' trước, rồi tới 'data'.
        final fromUser = raw['user'];
        if (fromUser is Map<String, dynamic>) {
          map = fromUser;
        } else {
          final fromData = raw['data'];
          map = (fromData is Map<String, dynamic>) ? fromData : raw;
        }
      }
      return map.isNotEmpty ? map : {'data': raw};
    } on DioException catch (e) {
      final message = _extractMessage(e.response?.data);
      throw Exception(
        'Lấy thông tin tài khoản thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  // NEW: flat user info alias GET /api/v1/users/me
  Future<Map<String, dynamic>> getUserMe() async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get(
        '/api/v1/users/me',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final raw = res.data;
      if (raw is Map<String, dynamic>) {
        final data = raw['data'];
        return (data is Map<String, dynamic>) ? data : raw;
      }
      return {'data': raw};
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Lấy thông tin người dùng thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<void> logout() async {
    final client = await _clientFuture;
    await client.logout();
  }

  Future<List<Job>> getJobs({
    String? category,
    int page = 1,
    int pageSize = 10,
  }) async {
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
      throw Exception(
        'Tải danh sách việc thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  // Search Jobs: GET /api/v1/jobs/search?q=&page=&size=&location=&company=&minSalary=&maxSalary
  Future<JobsSearchResult> searchJobs({
    required String q,
    int page = 1,
    int size = 10,
    String? location,
    String? company,
    int? minSalary,
    int? maxSalary,
  }) async {
    final client = await _clientFuture;
    try {
      final query = <String, dynamic>{'q': q, 'page': page, 'size': size};
      if (location != null && location.isNotEmpty) query['location'] = location;
      if (company != null && company.isNotEmpty) query['company'] = company;
      if (minSalary != null) query['minSalary'] = minSalary;
      if (maxSalary != null) query['maxSalary'] = maxSalary;

      final res = await client.dio.get(
        '/api/v1/jobs/search',
        queryParameters: query,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      // Meta theo ResultPaginationDTO: {page, pageSize, pages, total}
      Map<String, dynamic>? meta = extractMeta(res.data);
      int asInt(dynamic v, [int fallback = 0]) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v?.toString() ?? '') ?? fallback;
      }

      final pageMeta = asInt(meta?['page'], page);
      final sizeMeta = asInt(meta?['pageSize'], size);
      final pagesMeta = asInt(meta?['pages'], 1);
      final totalMeta = asInt(meta?['total'], 0);

      // Danh sách phân trang nằm trong data.result (hoặc content/items...)
      final listRaw = unwrapPageList(res.data);
      final items = listRaw.map<Job>((m) => Job.fromJson(m)).toList();

      return JobsSearchResult(
        items: items,
        page: pageMeta <= 0 ? 1 : pageMeta,
        pageSize: sizeMeta <= 0 ? size : sizeMeta,
        pages: pagesMeta <= 0 ? 1 : pagesMeta,
        total: totalMeta,
      );
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Tìm kiếm thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<Job> getJob(String id) async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get(
        '/api/v1/jobs/$id',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final data = res.data;
      Map<String, dynamic> map = {};
      if (data is Map<String, dynamic>) {
        map = (data['data'] is Map<String, dynamic>)
            ? data['data'] as Map<String, dynamic>
            : data;
      }
      return Job.fromJson(map);
    } on DioException catch (e) {
      final message = _extractMessage(e.response?.data);
      throw Exception(
        'Tải chi tiết việc thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  // New: Job Detail (ResJobDetailDTO)
  Future<JobDetail> getJobDetail(String id) async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get(
        '/api/v1/jobs/$id',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final raw = (res.data is Map<String, dynamic>)
          ? (res.data['data'] ?? res.data)
          : res.data;
      final map = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
      return JobDetail.fromJson(map);
    } on DioException catch (e) {
      final message = _extractMessage(e.response?.data);
      throw Exception(
        'Tải chi tiết việc thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  // Saved Jobs
  Future<List<SavedJob>> getSavedJobs() async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get(
        '/api/v1/saved-jobs',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return parseList<SavedJob>(res.data, (m) => SavedJob.fromJson(m));
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Tải danh sách đã lưu thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<bool> saveJob(String jobId) async {
    final client = await _clientFuture;
    try {
      await client.dio.post(
        '/api/v1/saved-jobs',
        queryParameters: {'jobId': jobId},
      );
      return true;
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Lưu job thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<bool> unsaveBySavedId(String savedId) async {
    final client = await _clientFuture;
    try {
      await client.dio.delete('/api/v1/saved-jobs/$savedId');
      return true;
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Bỏ lưu job thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<bool> unsaveByJobId(String jobId) async {
    final client = await _clientFuture;
    try {
      await client.dio.delete(
        '/api/v1/saved-jobs/$jobId',
        queryParameters: {'byJobId': true},
      );
      return true;
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Bỏ lưu job thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
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
  Future<String> uploadCvBytes(
    Uint8List bytes,
    String filename, {
    String folder = 'resume',
  }) async {
    final client = await _clientFuture;
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        'folder': folder,
      });
      final res = await client.dio.post('/api/v1/files', data: form);
      final data = (res.data is Map<String, dynamic>)
          ? (res.data['data'] ?? res.data)
          : res.data;
      if (data is Map<String, dynamic>) {
        final fileName = data['fileName'] ?? data['filename'] ?? data['name'];
        return fileName?.toString() ?? '';
      }
      return '';
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Upload CV thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  String buildResumeUrl(String fileName, {String folder = 'resume'}) {
    if (fileName.isEmpty) return '';
    return '/storage/$folder/$fileName';
  }

  // Tạo bản ghi Resume cho CV đã tải lên (job null)
  Future<bool> createResumeRecord({
    required String fileName,
    String? email,
  }) async {
    final client = await _clientFuture;
    try {
      final acc = await _getAccountSafe();
      final uidRaw =
          acc['id'] ??
          acc['userId'] ??
          (acc['user'] is Map ? acc['user']['id'] : null);
      int? uid = uidRaw is int
          ? uidRaw
          : int.tryParse(uidRaw?.toString() ?? '');
      if (uid == null) throw Exception('Không tìm thấy user.id để tạo CV');
      final payload = {
        if (email != null && email.isNotEmpty) 'email': email,
        'url': fileName,
        'user': {'id': uid},
      };
      await client.dio.post(
        '/api/v1/resumes',
        data: payload,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return true;
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Tạo CV thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<Map<String, dynamic>> _getAccountSafe() async {
    final acc = await getAccount();
    return acc;
  }

  Future<bool> hasAppliedJob(String jobId) async {
    try {
      final acc = await _getAccountSafe();
      final uidRaw =
          acc['id'] ??
          acc['userId'] ??
          (acc['user'] is Map ? acc['user']['id'] : null);
      int? uid = uidRaw is int
          ? uidRaw
          : int.tryParse(uidRaw?.toString() ?? '');
      if (uid == null) return false;
      return await hasAppliedJobByUser(jobId, uid);
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasAppliedJobByUser(String jobId, int userId) async {
    final client = await _clientFuture;
    try {
      final filter = Uri.encodeQueryComponent(
        'user.id==$userId and job.id==$jobId',
      );
      final res = await client.dio.get(
        '/api/v1/resumes',
        queryParameters: {'filter': filter, 'page': 1, 'size': 1},
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

  Future<bool> applyResumeForJob({
    required String jobId,
    String? url,
    String status = 'PENDING',
    String? email,
  }) async {
    final client = await _clientFuture;
    try {
      final acc = await _getAccountSafe();
      final uidRaw =
          acc['id'] ??
          acc['userId'] ??
          (acc['user'] is Map ? acc['user']['id'] : null);
      int? uid = uidRaw is int
          ? uidRaw
          : int.tryParse(uidRaw?.toString() ?? '');
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
      throw Exception(
        'Ứng tuyển thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<List<Resume>> getMyResumes({int page = 0, int pageSize = 10}) async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get(
        '/api/v1/resumes/by-user',
        queryParameters: {'page': page, 'size': pageSize},
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return parsePageList<Resume>(res.data, (m) => Resume.fromJson(m));
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Tải hồ sơ của tôi thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  // Chỉ lấy “CV đã tải lên” (resume có job == null) của user hiện tại
  Future<List<Resume>> getMyUploadedResumes({int page = 0, int pageSize = 10}) async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get(
        '/api/v1/resumes/my-uploads',
        queryParameters: {'page': page, 'size': pageSize},
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return parsePageList<Resume>(res.data, (m) => Resume.fromJson(m));
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Tải CV đã tải lên thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  // Debug/raw: trả thẳng danh sách map từ resp.data['result'] nếu có
  Future<List<Map<String, dynamic>>> getMyUploadsRaw({int page = 0, int pageSize = 10}) async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get(
        '/api/v1/resumes/my-uploads',
        queryParameters: {'page': page, 'size': pageSize},
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final root = res.data;
      debugPrint('[/my-uploads] resp.data = '+(root?.toString() ?? 'null'));
      if (root is Map<String, dynamic>) {
        final result = root['result'];
        if (result is List) {
          return result.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        }
      } else if (root is List) {
        return root.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
      // Fallback qua parser tolerant
      return unwrapPageList(root);
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception('getMyUploads failed: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}');
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

  // New: Company Detail (ResCompanyDetailDTO)
  Future<CompanyDetail> getCompanyDetail(String id) async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get(
        '/api/v1/companies/$id',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final raw = (res.data is Map<String, dynamic>)
          ? (res.data['data'] ?? res.data)
          : res.data;
      final map = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
      return CompanyDetail.fromJson(map);
    } on DioException catch (e) {
      final message = _extractMessage(e.response?.data);
      throw Exception(
        'Tải chi tiết công ty thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  // ===== Skills & Subscriber (Job by Email) =====
  Future<List<Map<String, dynamic>>> fetchSkills({
    int page = 1,
    int size = 100,
    String sort = 'createdAt,desc',
  }) async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get(
        '/api/v1/skills',
        queryParameters: {'page': page, 'size': size, 'sort': sort},
        options: Options(headers: {'Accept': 'application/json'}),
      );
      // Trả về list dạng [{id, name}...]
      final list = unwrapPageList(res.data);
      return list
          .map(
            (e) => {
              'id': e['id']?.toString(),
              'name': e['name']?.toString() ?? e['title']?.toString() ?? '',
            },
          )
          .toList();
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Tải danh sách kỹ năng thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<Subscriber?> getSubscriber() async {
    final client = await _clientFuture;
    try {
      // Chỉ gọi khi đã đăng nhập
      final token = await client.secureStorage.read(key: 'accessToken');
      if (token == null || token.isEmpty) {
        return null;
      }
      // Ưu tiên endpoint /subscribers/me (backend đã hỗ trợ), fallback sang GET /subscribers
      Response res;
      try {
        res = await client.dio.get(
          '/api/v1/subscribers/me',
          options: Options(headers: {'Accept': 'application/json'}),
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          // Chưa có subscriber cho user hiện tại
          return null;
        }
        // Fallback: lấy danh sách và chọn phần tử đầu tiên nếu có
        res = await client.dio.get(
          '/api/v1/subscribers',
          options: Options(headers: {'Accept': 'application/json'}),
        );
      }
      final raw = (res.data is Map<String, dynamic>)
          ? (res.data['data'] ?? res.data)
          : res.data;
      if (raw is Map<String, dynamic>) return Subscriber.fromJson(raw);
      // Một số backend trả danh sách một phần tử
      final list = unwrapList(res.data);
      if (list.isNotEmpty) return Subscriber.fromJson(list.first);
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null; // chưa có subscriber
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Tải subscriber thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<Subscriber> createSubscriber({
    required String email,
    required String name,
    required List<int> skillIds,
  }) async {
    final client = await _clientFuture;
    try {
      final payload = {
        'email': email,
        'name': name,
        'skills': skillIds.map((id) => {'id': id}).toList(),
      };
      final res = await client.dio.post(
        '/api/v1/subscribers',
        data: payload,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final raw = (res.data is Map<String, dynamic>)
          ? (res.data['data'] ?? res.data)
          : res.data;
      final map = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
      return Subscriber.fromJson(map);
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Tạo subscriber thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<Subscriber> updateSubscriber({
    required String id,
    required String email,
    required String name,
    required List<int> skillIds,
  }) async {
    final client = await _clientFuture;
    try {
      final payload = {
        'id': id,
        'email': email,
        'name': name,
        'skills': skillIds.map((sid) => {'id': sid}).toList(),
      };
      final res = await client.dio.put(
        '/api/v1/subscribers',
        data: payload,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final raw = (res.data is Map<String, dynamic>)
          ? (res.data['data'] ?? res.data)
          : res.data;
      final map = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
      return Subscriber.fromJson(map);
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Cập nhật subscriber thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<bool> deleteSubscriber(String id) async {
    final client = await _clientFuture;
    try {
      await client.dio.delete(
        '/api/v1/subscribers/$id',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404)
        return true; // không còn subscriber cũng coi như đã tắt
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Hủy đăng ký nhận job thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<bool> updateAccount({
    String? name,
    String? email,
    String? gender,
    String? address,
    int? age,
  }) async {
    final client = await _clientFuture;
    try {
      final payload = <String, dynamic>{
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (gender != null) 'gender': gender,
        if (address != null) 'address': address,
        if (age != null) 'age': age,
      };
      await client.dio.put(
        '/api/v1/auth/account',
        data: payload,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return true;
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Cập nhật tài khoản thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  // NEW: update current user via PUT /api/v1/users
  Future<bool> updateUser({
    String? name,
    String? gender,
    String? address,
    int? age,
    String? company,
  }) async {
    final client = await _clientFuture;
    try {
      final payload = <String, dynamic>{
        if (name != null) 'name': name,
        if (gender != null) 'gender': gender,
        if (address != null) 'address': address,
        if (age != null) 'age': age,
        if (company != null) 'company': company,
      };
      await client.dio.put(
        '/api/v1/users',
        data: payload,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return true;
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Cập nhật người dùng thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final client = await _clientFuture;
    try {
      await client.dio.post(
        '/api/v1/auth/change-password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return true;
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Đổi mật khẩu thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
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

  // Home Banners: GET /api/v1/banners/home
  Future<List<HomeBanner>> getHomeBanners() async {
    final client = await _clientFuture;
    try {
      final res = await client.dio.get(
        '/api/v1/banners/home',
        options: Options(
          headers: {'Accept': 'application/json'},
          extra: {'skipAuth': true},
        ),
      );
      // Backend có thể trả mảng trực tiếp trong data hoặc root
      return parseList<HomeBanner>(res.data, (m) => HomeBanner.fromJson(m));
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Tải banner trang chủ thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }

  // Featured companies (with logos). Fallback to paginated list filtered by logo.
  Future<List<CompanyBrief>> getTopCompanies({
    int page = 1,
    int size = 12,
  }) async {
    final client = await _clientFuture;
    try {
      // Ưu tiên endpoint chuyên biệt nếu backend có: /companies/featured
      Response res;
      try {
        res = await client.dio.get(
          '/api/v1/companies/featured',
          queryParameters: {
            'limit': size,
          },
          options: Options(
            headers: {'Accept': 'application/json'},
            extra: {'skipAuth': true},
          ),
        );
      } on DioException catch (e) {
        // Fallback sang danh sách chung
        if (e.response?.statusCode != 404) rethrow;
        res = await client.dio.get(
          '/api/v1/companies',
          queryParameters: {
            'page': page,
            'size': size,
            'sort': 'id,desc',
            'filter': 'logo!=null',
          },
          options: Options(
            headers: {'Accept': 'application/json'},
            extra: {'skipAuth': true},
          ),
        );
      }
      // Backend có thể trả data dạng list trực tiếp hoặc trong data.result/content
      return parsePageList<CompanyBrief>(
            res.data,
            (m) => CompanyBrief.fromJson(m),
          ).isNotEmpty
          ? parsePageList<CompanyBrief>(
              res.data,
              (m) => CompanyBrief.fromJson(m),
            )
          : parseList<CompanyBrief>(res.data, (m) => CompanyBrief.fromJson(m));
    } on DioException catch (e) {
      final message = extractMessage(e.response?.data);
      throw Exception(
        'Tải danh sách công ty thất bại: ${e.response?.statusCode ?? ''}${message.isNotEmpty ? ' - $message' : ''}',
      );
    }
  }
}
