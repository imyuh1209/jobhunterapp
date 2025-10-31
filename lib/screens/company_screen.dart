import 'package:flutter/material.dart';

import '../models/job.dart';
import '../services/api_service.dart';
import 'job_detail_screen.dart';

class CompanyScreen extends StatefulWidget {
  final String companyName;
  final String logoUrl;
  const CompanyScreen({super.key, required this.companyName, this.logoUrl = ''});

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  final _api = ApiService();
  late Future<List<Job>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getJobs(pageSize: 50);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.companyName)),
      body: FutureBuilder<List<Job>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Lỗi tải dữ liệu: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }
          final allJobs = snapshot.data ?? const <Job>[];
          final jobs = allJobs.where((j) {
            final a = j.company.trim().toLowerCase();
            final b = widget.companyName.trim().toLowerCase();
            return a == b || a.contains(b) || b.contains(a);
          }).toList();

          return LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CompanyHeader(name: widget.companyName, logoUrl: widget.logoUrl),
                    const SizedBox(height: 16),
                    if (jobs.isEmpty)
                      const Text('Chưa có việc đăng tuyển từ công ty này')
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 2 : 1,
                          childAspectRatio: isWide ? 2.8 : 2.2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: jobs.length,
                        itemBuilder: (context, index) {
                          final job = jobs[index];
                          return _JobCard(
                            job: job,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)),
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CompanyHeader extends StatelessWidget {
  final String name;
  final String logoUrl;
  const _CompanyHeader({required this.name, this.logoUrl = ''});

  @override
  Widget build(BuildContext context) {
    final Widget logo = logoUrl.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              logoUrl,
              height: 160,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _FallbackAvatar(company: name),
            ),
          )
        : _FallbackAvatar(company: name);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(width: 160, height: 120, child: Center(child: logo)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Nhà tuyển dụng', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  const _JobCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                height: 56,
                child: _CompanyLogo(logo: job.companyLogo, company: job.company),
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
                        const Icon(Icons.bolt, size: 16),
                        const SizedBox(width: 6),
                        Text(job.salary.isNotEmpty ? job.salary : '—'),
                      ],
                    ),
                  ],
                ),
              ),
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          logo,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _FallbackAvatar(company: company),
        ),
      );
    }
    return _FallbackAvatar(company: company);
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