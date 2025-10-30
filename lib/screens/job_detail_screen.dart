import 'package:flutter/material.dart';

import '../models/job.dart';
import '../services/api_service.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _api = ApiService();
  late Future<Job> _future;
  bool _saved = false;
  bool _loadingSave = false;

  @override
  void initState() {
    super.initState();
    _future = _api.getJob(widget.jobId);
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final ok = await _api.isJobSaved(widget.jobId);
    if (mounted) setState(() => _saved = ok);
  }

  Future<void> _toggleSave() async {
    if (_loadingSave) return;
    setState(() => _loadingSave = true);
    try {
      if (_saved) {
        await _api.unsaveByJobId(widget.jobId);
        if (mounted) setState(() => _saved = false);
      } else {
        await _api.saveJob(widget.jobId);
        if (mounted) setState(() => _saved = true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loadingSave = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        actions: [
          IconButton(
            tooltip: _saved ? 'Bỏ lưu' : 'Lưu công việc',
            onPressed: _loadingSave ? null : _toggleSave,
            icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
          ),
        ],
      ),
      body: FutureBuilder<Job>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          final job = snapshot.data;
          if (job == null) {
            return const Center(child: Text('Không tìm thấy công việc'));
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('${job.company} • ${job.location}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Text(job.description),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}