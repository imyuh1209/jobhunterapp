import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/saved_job.dart';
import 'job_detail_screen.dart';

class SavedJobsScreen extends StatefulWidget {
  const SavedJobsScreen({super.key});

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  final _api = ApiService();
  late Future<List<SavedJob>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getSavedJobs();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _api.getSavedJobs();
    });
  }

  Future<void> _unsave(String savedId) async {
    try {
      await _api.unsaveBySavedId(savedId);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Công việc đã lưu')),
      body: FutureBuilder<List<SavedJob>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('Bạn chưa lưu công việc nào'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final s = items[index];
                return ListTile(
                  title: Text(s.title.isNotEmpty ? s.title : '—'),
                  subtitle: Text('${s.company.isNotEmpty ? s.company : '—'} • ${s.location.isNotEmpty ? s.location : '—'}'),
                  trailing: IconButton(
                    tooltip: 'Bỏ lưu',
                    icon: const Icon(Icons.bookmark_remove),
                    onPressed: () => _unsave(s.savedId),
                  ),
                  onTap: () {
                    if (s.jobId.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: s.jobId)),
                    );
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