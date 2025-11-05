import 'package:flutter/material.dart';
import '../utils/format_utils.dart';

import '../models/company_detail.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import 'job_detail_screen.dart';

class CompanyScreen extends StatefulWidget {
  final String companyName;
  final String logoUrl;
  final String? companyId;
  const CompanyScreen({super.key, required this.companyName, this.logoUrl = '', this.companyId});

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  final _api = ApiService();
  Future<CompanyDetail>? _futureDetail;

  @override
  void initState() {
    super.initState();
    if (widget.companyId != null && widget.companyId!.isNotEmpty) {
      _futureDetail = _api.getCompanyDetail(widget.companyId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.companyName)),
      body: widget.companyId == null || widget.companyId!.isEmpty
          ? _buildFallbackList()
          : FutureBuilder<CompanyDetail>(
        future: _futureDetail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Lỗi tải dữ liệu: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }
          final detail = snapshot.data;
          final jobs = detail?.jobs ?? const <JobSimple>[];

          return LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CompanyHeader(name: detail?.name ?? widget.companyName, logoUrl: detail?.logo ?? widget.logoUrl),
                    const SizedBox(height: 16),
                    if (jobs.isEmpty)
                      const Text('Chưa có việc đăng tuyển từ công ty này')
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: jobs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final j = jobs[index];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                            child: ListTile(
                              title: Text(j.name),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: j.id)),
                                );
                              },
                            ),
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

  // Fallback: nếu không có companyId, giữ logic cũ lọc theo tên từ danh sách jobs
  Widget _buildFallbackList() {
    final future = _api.getJobs(pageSize: 50);
    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Lỗi tải dữ liệu: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        final allJobs = (snapshot.data as List?) ?? const <dynamic>[];
        final jobs = allJobs.where((j) {
          try {
            final name = (j.company as String).trim().toLowerCase();
            final b = widget.companyName.trim().toLowerCase();
            return name == b || name.contains(b) || b.contains(name);
          } catch (_) {
            return false;
          }
        }).toList();

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
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 100,
                                height: 80,
                                child: _CompanyLogo(logo: job.companyLogo, company: job.company),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(job.title, style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(FormatUtils.formatLocation(job.location), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.bolt, size: 16),
                                        const SizedBox(width: 6),
                                        Text(FormatUtils.formatSalaryFromTo(job.salaryFrom, job.salaryTo, isNegotiable: job.isNegotiable)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CompanyHeader extends StatelessWidget {
  final String name;
  final String logoUrl;
  const _CompanyHeader({required this.name, this.logoUrl = ''});

  @override
  Widget build(BuildContext context) {
    final String resolved = _resolveImageUrl(logoUrl);
    final Widget logo = logoUrl.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              resolved,
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

// _JobCard removed in favor of simpler ListTile for JobSimple

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
          _resolveImageUrl(logo),
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
  if (u.isEmpty) return u;
  if (u.startsWith('http://') || u.startsWith('https://')) return u;
  if (u.startsWith('/')) return '${ApiConfig.baseUrl}$u';
  return u;
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