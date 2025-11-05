import 'package:flutter/material.dart';

import '../models/job.dart';
import '../models/jobs_search_result.dart';
import '../services/api_service.dart';
import 'job_detail_screen.dart';
import '../utils/format_utils.dart';

class HiringJobsScreen extends StatefulWidget {
  const HiringJobsScreen({super.key});

  @override
  State<HiringJobsScreen> createState() => _HiringJobsScreenState();
}

class _HiringJobsScreenState extends State<HiringJobsScreen> {
  final _api = ApiService();
  late Future<List<Job>> _future;
  Future<JobsSearchResult>? _futureSearch;
  final _qCtl = TextEditingController();
  String _query = '';
  int _page = 1;
  final int _pageSize = 10;
  int _pages = 1;
  int _total = 0;
  // Bộ lọc nâng cao
  String? _filterLocation;
  String? _filterCompany;
  int? _minSalary;
  int? _maxSalary;
  final _locationCtl = TextEditingController();
  final _companyCtl = TextEditingController();
  final _minSalaryCtl = TextEditingController();
  final _maxSalaryCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _api.getJobs(page: 1, pageSize: 10);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đang tuyển'),
        actions: [
          IconButton(
            tooltip: 'Bộ lọc nâng cao',
            onPressed: _openFilters,
            icon: const Icon(Icons.filter_list),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _qCtl,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm công việc...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: (_query.isNotEmpty)
                    ? IconButton(
                        tooltip: 'Xóa',
                        onPressed: () {
                          setState(() {
                            _qCtl.clear();
                            _query = '';
                            _page = 1;
                            _futureSearch = null;
                          });
                        },
                        icon: const Icon(Icons.close),
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (val) {
                final q = val.trim();
                setState(() {
                  _query = q;
                  _refreshData();
                });
              },
            ),
          ),
        ),
      ),
      body: (_query.isNotEmpty || _hasFiltersActive())
          ? FutureBuilder<JobsSearchResult>(
              future: _futureSearch,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }
                final data = snapshot.data;
                final jobs = data?.items ?? const <Job>[];
                _pages = data?.pages ?? 1;
                _total = data?.total ?? jobs.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Kết quả cho "$_query" • ${jobs.length} việc • Trang $_page/$_pages',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Bộ lọc nâng cao',
                            onPressed: _openFilters,
                            icon: const Icon(Icons.filter_list),
                          ),
                          IconButton(
                            tooltip: 'Trang trước',
                            onPressed: _page > 1
                                ? () {
                                    setState(() {
                                      _page -= 1;
                                      _refreshData();
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            tooltip: 'Trang sau',
                            onPressed: _page < _pages
                                ? () {
                                    setState(() {
                                      _page += 1;
                                      _refreshData();
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                    if (((_filterLocation ?? '').isNotEmpty) || ((_filterCompany ?? '').isNotEmpty) || _minSalary != null || _maxSalary != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: -8,
                          children: [
                            if ((_filterLocation ?? '').isNotEmpty)
                              InputChip(
                                label: Text('Địa điểm: ${FormatUtils.formatLocation(_filterLocation!)}'),
                                onDeleted: () {
                                  setState(() {
                                    _filterLocation = null;
                                    _locationCtl.clear();
                                    _refreshData();
                                  });
                                },
                              ),
                            if ((_filterCompany ?? '').isNotEmpty)
                              InputChip(
                                label: Text('Công ty: ${_filterCompany}'),
                                onDeleted: () {
                                  setState(() {
                                    _filterCompany = null;
                                    _companyCtl.clear();
                                    _refreshData();
                                  });
                                },
                              ),
                            if (_minSalary != null || _maxSalary != null)
                              InputChip(
                                label: Text(
                                  'Lương: ${FormatUtils.formatSalaryRange('${_minSalary ?? ''}${_maxSalary != null ? ' - ${_maxSalary}' : ''} đ')}',
                                ),
                                onDeleted: () {
                                  setState(() {
                                    _minSalary = null;
                                    _maxSalary = null;
                                    _minSalaryCtl.clear();
                                    _maxSalaryCtl.clear();
                                    _refreshData();
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: LayoutBuilder(
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
                              return _JobCardCompact(
                                job: job,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            )
          : FutureBuilder<List<Job>>(
              future: _future,
              builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }
          final jobs = snapshot.data ?? const <Job>[];
          if (jobs.isEmpty) {
            return const Center(child: Text('Chưa có công việc đang tuyển'));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hasFiltersActive())
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: -8,
                    children: [
                      if ((_filterLocation ?? '').isNotEmpty)
                        InputChip(
                          label: Text('Địa điểm: ${FormatUtils.formatLocation(_filterLocation!)}'),
                          onDeleted: () {
                            setState(() {
                              _filterLocation = null;
                              _locationCtl.clear();
                              _refreshData();
                            });
                          },
                        ),
                      if ((_filterCompany ?? '').isNotEmpty)
                        InputChip(
                          label: Text('Công ty: ${_filterCompany}'),
                          onDeleted: () {
                            setState(() {
                              _filterCompany = null;
                              _companyCtl.clear();
                              _refreshData();
                            });
                          },
                        ),
                      if (_minSalary != null || _maxSalary != null)
                        InputChip(
                          label: Text(
                            'Lương: ${FormatUtils.formatSalaryRange('${_minSalary ?? ''}${_maxSalary != null ? ' - ${_maxSalary}' : ''} đ')}',
                          ),
                          onDeleted: () {
                            setState(() {
                              _minSalary = null;
                              _maxSalary = null;
                              _minSalaryCtl.clear();
                              _maxSalaryCtl.clear();
                              _refreshData();
                            });
                          },
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
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
                    return _JobCardCompact(
                      job: job,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)),
                        );
                      },
                    );
                  },
                );
              },
              ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Bộ lọc nâng cao', style: Theme.of(ctx).textTheme.titleMedium)),
                    IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Thành phố/Địa điểm'),
                const SizedBox(height: 6),
                TextField(
                  controller: _locationCtl,
                  decoration: const InputDecoration(hintText: 'VD: HANOI, DANANG, HOCHIMINH'),
                ),
                const SizedBox(height: 12),
                const Text('Công ty'),
                const SizedBox(height: 6),
                TextField(
                  controller: _companyCtl,
                  decoration: const InputDecoration(hintText: 'VD: Viettel, VNG, FPT'),
                ),
                const SizedBox(height: 12),
                const Text('Mức lương tối thiểu/tối đa'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minSalaryCtl,
                        decoration: const InputDecoration(hintText: 'Min'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxSalaryCtl,
                        decoration: const InputDecoration(hintText: 'Max'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _filterLocation = null;
                          _filterCompany = null;
                          _minSalary = null;
                          _maxSalary = null;
                          _locationCtl.clear();
                          _companyCtl.clear();
                          _minSalaryCtl.clear();
                          _maxSalaryCtl.clear();
                          _refreshData();
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Xóa bộ lọc'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterLocation = _locationCtl.text.trim().isEmpty ? null : _locationCtl.text.trim();
                          _filterCompany = _companyCtl.text.trim().isEmpty ? null : _companyCtl.text.trim();
                          _minSalary = _minSalaryCtl.text.trim().isEmpty ? null : int.tryParse(_minSalaryCtl.text.trim());
                          _maxSalary = _maxSalaryCtl.text.trim().isEmpty ? null : int.tryParse(_maxSalaryCtl.text.trim());
                          _refreshData();
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Áp dụng'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _hasFiltersActive() {
    return ((_filterLocation ?? '').isNotEmpty) || ((_filterCompany ?? '').isNotEmpty) || _minSalary != null || _maxSalary != null;
  }

  void _refreshData() {
    _page = 1;
    if (_query.isNotEmpty || _hasFiltersActive()) {
      _futureSearch = _api.searchJobs(
        q: _query,
        page: _page,
        size: _pageSize,
        location: _filterLocation,
        company: _filterCompany,
        minSalary: _minSalary,
        maxSalary: _maxSalary,
      );
    } else {
      _futureSearch = null;
      _future = _api.getJobs(page: 1, pageSize: _pageSize);
    }
  }
}

class _JobCardCompact extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  const _JobCardCompact({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    height: 64,
                    child: _LogoOrAvatar(logo: job.companyLogo, company: job.company),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job.title, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                [job.company, FormatUtils.formatLocation(job.location)]
                                    .where((e) => e.isNotEmpty)
                                    .join(' • '),
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      FormatUtils.formatSalaryFromTo(job.salaryFrom, job.salaryTo, isNegotiable: job.isNegotiable),
                      style: Theme.of(context).textTheme.bodySmall,
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

class _LogoOrAvatar extends StatelessWidget {
  final String logo;
  final String company;
  const _LogoOrAvatar({required this.logo, required this.company});

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
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        (company.isNotEmpty ? company[0] : '?').toUpperCase(),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}