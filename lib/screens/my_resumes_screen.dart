import 'package:flutter/material.dart';
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
  late Future<List<Resume>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getMyResumes();
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
      appBar: AppBar(title: const Text('Hồ sơ đã ứng tuyển')),
      body: FutureBuilder<List<Resume>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
          }
          final items = snapshot.data ?? const <Resume>[];
          if (items.isEmpty) {
            return const Center(child: Text('Bạn chưa ứng tuyển công việc nào'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _api.getMyResumes();
              });
            },
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = items[i];
                final status = r.status ?? 'PENDING';
                final color = _statusColor(status);
                return ListTile(
                  leading: CircleAvatar(backgroundColor: color, child: const Icon(Icons.assignment_turned_in, color: Colors.white)),
                  title: Text(r.jobTitle ?? 'Hồ sơ ứng tuyển'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trạng thái: $status'),
                      if ((r.url ?? '').isNotEmpty) Text('CV: ${r.url}'),
                      if ((r.email ?? '').isNotEmpty) Text('Email: ${r.email}'),
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}