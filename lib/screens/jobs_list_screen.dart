import 'package:flutter/material.dart';

import '../models/job.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import 'job_detail_screen.dart';
import 'account_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import '../widgets/private_route.dart';
import '../widgets/header_app_bar.dart';
import 'login_screen.dart';
import 'saved_jobs_screen.dart';
import 'my_resumes_screen.dart';

class JobsListScreen extends StatefulWidget {
  final String? category;
  const JobsListScreen({super.key, this.category});

  @override
  State<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends State<JobsListScreen> {
  final _api = ApiService();
  late Future<List<Job>> _future;
  bool _isAdmin = false;

  Future<void> _loadRole() async {
    try {
      final acc = await _api.getAccount();
      final roles = <String>{};
      final role = acc['role'];
      if (role is String) roles.add(role);
      final rolesArr = acc['roles'];
      if (rolesArr is List) {
        for (final r in rolesArr) {
          if (r is String) roles.add(r);
        }
      }
      final auths = acc['authorities'];
      if (auths is List) {
        for (final a in auths) {
          if (a is String) roles.add(a);
        }
      }
      setState(() {
        _isAdmin = roles.any((r) => r.toUpperCase().contains('ADMIN'));
      });
    } catch (_) {
      setState(() {
        _isAdmin = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _api.getJobs(category: widget.category);
    _loadRole();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderAppBar(
        showAdmin: _isAdmin,
        onSearch: (category) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => JobsListScreen(category: category)),
          );
        },
        onOpenAdmin: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PrivateRoute(
                builder: (_) => const AdminDashboardScreen(),
                allowedRoles: const ['ADMIN'],
              ),
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
        onOpenMyResumes: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PrivateRoute(builder: (_) => const MyResumesScreen())),
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
          return LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final cross = isWide ? 2 : 1;
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  childAspectRatio: isWide ? 2.8 : 2.2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                padding: const EdgeInsets.all(16),
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  return _JobCard(
                    job: job,
                    api: _api,
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
          );
        },
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  final ApiService? api;
  const _JobCard({required this.job, required this.onTap, this.api});

  @override
  Widget build(BuildContext context) {
    final logo = job.companyLogo;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                height: 56,
                child: _CompanyLogo(logo: logo, company: job.company),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text(job.location, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.attach_money, size: 16),
                        const SizedBox(width: 6),
                        Text(job.salary.isNotEmpty ? job.salary : '—'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  _SaveStatus(jobId: job.id, api: api),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  final String logo;
  final String company;
  const _CompanyLogo({required this.logo, required this.company});

  @override
  Widget build(BuildContext context) {
    if (logo.isNotEmpty) {
      final resolved = _resolveImageUrl(logo);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          resolved,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _FallbackAvatar(company: company),
        ),
      );
    }
    return _FallbackAvatar(company: company);
  }
}

String _resolveImageUrl(String url) {
  final u = url.trim();
  if (u.startsWith('http://') || u.startsWith('https://')) return u;
  if (u.startsWith('/')) return '${ApiConfig.baseUrl}$u';
  return u;
}

class _SaveStatus extends StatelessWidget {
  final String jobId;
  final ApiService? api;
  const _SaveStatus({required this.jobId, this.api});

  @override
  Widget build(BuildContext context) {
    final service = api;
    if (service == null) {
      return Column(
        children: [
          const Icon(Icons.favorite_border, size: 20),
          const SizedBox(height: 4),
          Text('Lưu', style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }
    return FutureBuilder<bool>(
      future: service.isJobSaved(jobId),
      builder: (context, snapshot) {
        final saved = snapshot.data == true;
        return Column(
          children: [
            Icon(
              saved ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: saved ? Theme.of(context).colorScheme.error : null,
            ),
            const SizedBox(height: 4),
            Text(saved ? 'Đã lưu' : 'Lưu', style: Theme.of(context).textTheme.bodySmall),
          ],
        );
      },
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  final String company;
  const _FallbackAvatar({required this.company});

  @override
  Widget build(BuildContext context) {
    final initials = company.isNotEmpty ? company.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join() : '?';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      child: Center(
        child: Text(initials.toUpperCase(), style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}