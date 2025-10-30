import 'package:flutter/material.dart';

import '../models/job.dart';
import '../services/api_service.dart';
import 'job_detail_screen.dart';
import 'account_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import '../widgets/private_route.dart';
import '../widgets/header_app_bar.dart';
import 'login_screen.dart';
import 'saved_jobs_screen.dart';

class JobsListScreen extends StatefulWidget {
  final String? category;
  const JobsListScreen({super.key, this.category});

  @override
  State<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends State<JobsListScreen> {
  final _api = ApiService();
  late Future<List<Job>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getJobs(category: widget.category);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderAppBar(
        onSearch: (category) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => JobsListScreen(category: category)),
          );
        },
        onOpenAdmin: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PrivateRoute(builder: (_) => const AdminDashboardScreen()),
            ),
          );
        },
        onOpenAccount: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AccountScreen()),
          );
        },
        onOpenSavedJobs: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PrivateRoute(builder: (_) => const SavedJobsScreen())),
          );
        },
        onLogout: () async {
          try {
            await _api.logout();
          } catch (_) {}
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        },
      ),
      body: FutureBuilder<List<Job>>(
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
          final jobs = snapshot.data ?? [];
          if (jobs.isEmpty) {
            return const Center(child: Text('Không có việc phù hợp'));
          }
          return ListView.separated(
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final job = jobs[index];
              return ListTile(
                title: Text(job.title),
                subtitle: Text('${job.company} • ${job.location}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => JobDetailScreen(jobId: job.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}