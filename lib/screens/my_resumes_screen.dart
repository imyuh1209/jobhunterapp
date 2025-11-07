import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../models/resume.dart';
import 'job_detail_screen.dart';

class MyResumesScreen extends StatefulWidget {
  const MyResumesScreen({super.key});

  @override
  State<MyResumesScreen> createState() => _MyResumesScreenState();
}

class _MyResumesScreenState extends State<MyResumesScreen> {
  final _api = ApiService();
  late Future<List<Resume>> _futureApplied;
  late Future<List<Resume>> _futureUploaded;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _futureApplied = _api.getMyResumes(page: 0, pageSize: 20);
    _futureUploaded = _api.getMyUploadedResumes(page: 0, pageSize: 10);
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'REVIEWING':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My CV')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _futureApplied = _api.getMyResumes(page: 0, pageSize: 20);
            _futureUploaded = _api.getMyUploadedResumes(page: 0, pageSize: 10);
          });
        },
        child: ListView(
          children: [
            // Section: CV đã tạo/đã ứng tuyển (job != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('CV đã tạo/đã ứng tuyển', style: Theme.of(context).textTheme.titleMedium),
            ),
            FutureBuilder<List<Resume>>(
              future: _futureApplied,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Lỗi tải dữ liệu: ${snapshot.error}'),
                  );
                }
                final items = snapshot.data ?? const <Resume>[];
                return Column(children: _buildAppliedResumes(items));
              },
            ),
            const Divider(height: 1),
            // Section: CV đã tải lên (job == null) + nút upload
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(child: Text('CV đã tải lên', style: Theme.of(context).textTheme.titleMedium)),
                  FilledButton.icon(
                    onPressed: _uploading ? null : _pickAndUpload,
                    icon: const Icon(Icons.upload_file),
                    label: _uploading ? const Text('Đang tải...') : const Text('Tải CV lên'),
                  ),
                ],
              ),
            ),
            FutureBuilder<List<Resume>>(
              future: _futureUploaded,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Lỗi tải dữ liệu: ${snapshot.error}'),
                  );
                }
                final items = snapshot.data ?? const <Resume>[];
                return Column(children: _buildUploadedResumes(items));
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAppliedResumes(List<Resume> items) {
    final applied = items.where((r) => (r.jobId ?? '').isNotEmpty).toList();
    if (applied.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Chưa có hồ sơ ứng tuyển'),
        )
      ];
    }
    return List<Widget>.generate(applied.length, (i) {
      final r = applied[i];
      final status = r.status ?? 'PENDING';
      final color = _statusColor(status);
      return ListTile(
        leading: CircleAvatar(backgroundColor: color, child: const Icon(Icons.assignment_turned_in, color: Colors.white)),
        title: Text(r.jobTitle ?? 'Hồ sơ ứng tuyển'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trạng thái: $status'),
            if ((r.companyName ?? '').isNotEmpty) Text('Công ty: ${r.companyName}'),
            if ((r.url ?? '').isNotEmpty) Text('CV: ${r.url}'),
          ],
        ),
        onTap: () {
          final jid = r.jobId;
          if (jid != null && jid.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: jid)),
            );
          }
        },
        trailing: IconButton(
          tooltip: 'Xem CV',
          icon: const Icon(Icons.open_in_new),
          onPressed: () => _openResume(r),
        ),
      );
    });
  }

  List<Widget> _buildUploadedResumes(List<Resume> items) {
    final uploaded = items.where((r) => (r.jobId ?? '').isEmpty).toList();
    if (uploaded.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Chưa có CV tải lên'),
        )
      ];
    }
    return List<Widget>.generate(uploaded.length, (i) {
      final r = uploaded[i];
      return ListTile(
        leading: const CircleAvatar(child: Icon(Icons.description)),
        title: Text(r.url ?? 'CV đã tải lên'),
        subtitle: Text(r.createdAt?.toIso8601String() ?? ''),
        trailing: IconButton(
          tooltip: 'Xem CV',
          icon: const Icon(Icons.open_in_new),
          onPressed: () => _openResume(r),
        ),
      );
    });
  }

  Future<void> _pickAndUpload() async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      final f = result?.files.first;
      if (f == null) return;
      // Giới hạn kích thước, ví dụ 10MB
      final max = 10 * 1024 * 1024;
      if ((f.size ?? 0) > max) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File quá lớn (>10MB)')),
        );
        return;
      }
      final fileName = await _api.uploadCvBytes(f.bytes!, f.name, folder: 'resume');
      if (fileName.isEmpty) {
        throw Exception('Upload thất bại');
      }
      await _api.createResumeRecord(fileName: fileName);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tải CV lên thành công')));
      setState(() {
        _futureApplied = _api.getMyResumes(page: 0, pageSize: 20);
        _futureUploaded = _api.getMyUploadedResumes(page: 0, pageSize: 10);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _openResume(Resume r) async {
    String? url = r.urlStorage;
    if (url == null || url.isEmpty) {
      final fileName = r.url ?? '';
      if (fileName.isEmpty) return;
      url = '/storage/resume/$fileName';
    }
    final full = url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';
    final uri = Uri.tryParse(full);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}