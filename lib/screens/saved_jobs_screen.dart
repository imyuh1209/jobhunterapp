import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/saved_job.dart';
import '../utils/format_utils.dart';
import '../utils/url_utils.dart';
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
                String _initial(String v) => (v.isNotEmpty ? v.trim()[0] : '•').toUpperCase();
                final logoUrl = buildImageUrl(s.companyLogo);
                return ListTile(
                  leading: SizedBox(
                    width: 48,
                    height: 48,
                    child: logoUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              logoUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => CircleAvatar(child: Text(_initial(s.company))),
                            ),
                          )
                        : CircleAvatar(child: Text(_initial(s.company))),
                  ),
                  title: Text(s.title.isNotEmpty ? s.title : '—'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${s.company.isNotEmpty ? s.company : '—'} • ${s.location.isNotEmpty ? s.location : '—'}'),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            FormatUtils.formatSalaryFromTo(
                              s.salaryFrom,
                              s.salaryTo,
                              isNegotiable: s.isNegotiable,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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