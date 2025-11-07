import 'package:flutter/material.dart';

import '../models/job.dart';
import '../models/jobs_search_result.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import 'job_detail_screen.dart';
import '../utils/format_utils.dart';
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
  Future<JobsSearchResult>? _futureSearch;
  bool _isAdmin = false;
  String? _query; // từ khóa tìm kiếm hiện tại
  int _page = 1;
  final int _pageSize = 10;
  int _pages = 1;
  int _total = 0;
  bool _showHiring = false; // chế độ hiển thị: đang tuyển
  bool _filtersVisible = false; // hiển thị panel bộ lọc khi nhấn icon

  // Bộ lọc nâng cao
  String? _filterLocation;
  String? _filterCompany;
  int? _minSalary;
  int? _maxSalary;
  final _locationCtl = TextEditingController();
  final _companyCtl = TextEditingController();
  final _minSalaryCtl = TextEditingController();
  final _maxSalaryCtl = TextEditingController();

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
    _query = widget.category;
    if ((_query ?? '').isNotEmpty) {
      _futureSearch = _api.searchJobs(
        q: _query!,
        page: _page,
        size: _pageSize,
        location: _filterLocation,
        company: _filterCompany,
        minSalary: _minSalary,
        maxSalary: _maxSalary,
      );
    } else {
      _future = _api.getJobs(category: _query);
    }
    _loadRole();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderAppBar(
        showAdmin: _isAdmin,
        onSearch: (category) {
          setState(() {
            _query = category.trim();
            _page = 1;
            if ((_query ?? '').isNotEmpty) {
              _futureSearch = _api.searchJobs(
                q: _query!,
                page: _page,
                size: _pageSize,
                location: _filterLocation,
                company: _filterCompany,
                minSalary: _minSalary,
                maxSalary: _maxSalary,
              );
            } else {
              _future = _api.getJobs(category: _query);
            }
          });
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
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AccountScreen()));
        },
        onOpenSavedJobs: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PrivateRoute(builder: (_) => const SavedJobsScreen()),
            ),
          );
        },
        onOpenMyResumes: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PrivateRoute(builder: (_) => const MyResumesScreen()),
            ),
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
      body: (_query ?? '').isNotEmpty
          ? FutureBuilder<JobsSearchResult>(
              future: _futureSearch,
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
                final data = snapshot.data;
                final jobs = data?.items ?? const <Job>[];
                _pages = data?.pages ?? 1;
                _total = data?.total ?? jobs.length;
                // Fallback lọc client-side nếu backend trả về danh sách không lọc theo q
                final q = (_query ?? '').trim().toLowerCase();
                List<Job> filtered = jobs;
                if (q.isNotEmpty) {
                  filtered = filtered.where((j) {
                    final title = j.title.toLowerCase();
                    final location = j.location.toLowerCase();
                    final company = j.company.toLowerCase();
                    return title.contains(q) ||
                        location.contains(q) ||
                        company.contains(q);
                  }).toList();
                }
                // Áp dụng bộ lọc nâng cao client-side nếu backend chưa hỗ trợ
                if ((_filterLocation ?? '').isNotEmpty) {
                  final loc = _filterLocation!.toLowerCase();
                  filtered = filtered
                      .where((j) => j.location.toLowerCase().contains(loc))
                      .toList();
                }
                if ((_filterCompany ?? '').isNotEmpty) {
                  final c = _filterCompany!.toLowerCase();
                  filtered = filtered
                      .where((j) => j.company.toLowerCase().contains(c))
                      .toList();
                }
                int _parseSalary(String s) {
                  final onlyDigits = s.replaceAll(RegExp(r'[^0-9]'), '');
                  return int.tryParse(onlyDigits) ?? 0;
                }

                if (_minSalary != null) {
                  filtered = filtered
                      .where((j) => _parseSalary(j.salary) >= _minSalary!)
                      .toList();
                }
                if (_maxSalary != null) {
                  filtered = filtered
                      .where((j) => _parseSalary(j.salary) <= _maxSalary!)
                      .toList();
                }
                if (jobs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Không có việc phù hợp với "$_query"'),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Kết quả cho "$_query" • ${filtered.length} việc • Trang $_page/$_pages',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Row(
                            children: [
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
                                          _futureSearch = _api.searchJobs(
                                            q: _query!,
                                            page: _page,
                                            size: _pageSize,
                                            location: _filterLocation,
                                            company: _filterCompany,
                                            minSalary: _minSalary,
                                            maxSalary: _maxSalary,
                                          );
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
                                          _futureSearch = _api.searchJobs(
                                            q: _query!,
                                            page: _page,
                                            size: _pageSize,
                                            location: _filterLocation,
                                            company: _filterCompany,
                                            minSalary: _minSalary,
                                            maxSalary: _maxSalary,
                                          );
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (((_filterLocation ?? '').isNotEmpty) ||
                        ((_filterCompany ?? '').isNotEmpty) ||
                        _minSalary != null ||
                        _maxSalary != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: -8,
                          children: [
                            if ((_filterLocation ?? '').isNotEmpty)
                              InputChip(
                                label: Text(
                                  'Địa điểm: ${FormatUtils.formatLocation(_filterLocation!)}',
                                ),
                                onDeleted: () {
                                  setState(() {
                                    _filterLocation = null;
                                    _locationCtl.clear();
                                    _page = 1;
                                    _futureSearch = _api.searchJobs(
                                      q: _query!,
                                      page: _page,
                                      size: _pageSize,
                                      location: _filterLocation,
                                      company: _filterCompany,
                                      minSalary: _minSalary,
                                      maxSalary: _maxSalary,
                                    );
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
                                    _page = 1;
                                    _futureSearch = _api.searchJobs(
                                      q: _query!,
                                      page: _page,
                                      size: _pageSize,
                                      location: _filterLocation,
                                      company: _filterCompany,
                                      minSalary: _minSalary,
                                      maxSalary: _maxSalary,
                                    );
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
                                    _page = 1;
                                    _futureSearch = _api.searchJobs(
                                      q: _query!,
                                      page: _page,
                                      size: _pageSize,
                                      minSalary: _minSalary,
                                      maxSalary: _maxSalary,
                                    );
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Việc làm'),
                            selected: !_showHiring,
                            onSelected: (v) {
                              if (v) setState(() => _showHiring = false);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Đang tuyển'),
                            selected: _showHiring,
                            onSelected: (v) {
                              if (v) setState(() => _showHiring = true);
                            },
                          ),
                          if (!_showHiring)
                            IconButton(
                              tooltip: 'Bộ lọc',
                              onPressed: () => setState(
                                () => _filtersVisible = !_filtersVisible,
                              ),
                              icon: const Icon(Icons.filter_list),
                            ),
                        ],
                      ),
                    ),
                    if (!_showHiring && _filtersVisible) _buildInlineFilters(),
                    Expanded(
                      child: _showHiring
                          ? FutureBuilder<List<Job>>(
                              future: _api.getJobs(page: 1, pageSize: 10),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      'Lỗi: ${snapshot.error}',
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  );
                                }
                                final jobs = snapshot.data ?? const <Job>[];
                                if (jobs.isEmpty) {
                                  return const Center(
                                    child: Text('Chưa có công việc đang tuyển'),
                                  );
                                }
                                return LayoutBuilder(
                                  builder: (ctx, constraints) {
                                    final isWide = constraints.maxWidth >= 900;
                                    final cross = isWide ? 2 : 1;
                                    return GridView.builder(
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: cross,
                                            childAspectRatio: isWide
                                                ? 2.8
                                                : 2.2,
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
                                                builder: (_) => JobDetailScreen(
                                                  jobId: job.id,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            )
                          : LayoutBuilder(
                              builder: (ctx, constraints) {
                                final isWide = constraints.maxWidth >= 900;
                                final cross = isWide ? 2 : 1;
                                return GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: cross,
                                        childAspectRatio: isWide ? 2.8 : 2.2,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final job = filtered[index];
                                    return _JobCard(
                                      job: job,
                                      api: _api,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                JobDetailScreen(jobId: job.id),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          const Spacer(),
                          Text(
                            _showHiring ? 'Đang tuyển' : 'Tổng: $_total việc',
                          ),
                        ],
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
                final filteredCount = jobs.where((j) {
                  final locOk =
                      _filterLocation == null ||
                      j.location.toLowerCase().contains(
                        (_filterLocation ?? '').toLowerCase(),
                      );
                  final compOk =
                      _filterCompany == null ||
                      j.company.toLowerCase().contains(
                        (_filterCompany ?? '').toLowerCase(),
                      );
                  final fromVal = j.salaryFrom ?? j.salaryTo ?? 0;
                  final toVal = j.salaryTo ?? j.salaryFrom ?? 0;
                  final minOk =
                      _minSalary == null ||
                      j.isNegotiable ||
                      fromVal >= (_minSalary ?? 0);
                  final maxOk =
                      _maxSalary == null ||
                      j.isNegotiable ||
                      (toVal == 0 ? true : toVal <= (_maxSalary ?? toVal));
                  return locOk && compOk && minOk && maxOk;
                }).length;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Việc làm'),
                            selected: !_showHiring,
                            onSelected: (v) {
                              if (v) setState(() => _showHiring = false);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Đang tuyển'),
                            selected: _showHiring,
                            onSelected: (v) {
                              if (v) setState(() => _showHiring = true);
                            },
                          ),
                          if (!_showHiring)
                            IconButton(
                              tooltip: 'Bộ lọc',
                              onPressed: () => setState(
                                () => _filtersVisible = !_filtersVisible,
                              ),
                              icon: const Icon(Icons.filter_list),
                            ),
                        ],
                      ),
                    ),
                    if (!_showHiring && _filtersVisible) _buildInlineFilters(),
                    Expanded(
                      child: _showHiring
                          ? FutureBuilder<List<Job>>(
                              future: _api.getJobs(page: 1, pageSize: 10),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      'Lỗi: ${snapshot.error}',
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  );
                                }
                                final jobs2 = snapshot.data ?? const <Job>[];
                                if (jobs2.isEmpty) {
                                  return const Center(
                                    child: Text('Chưa có công việc đang tuyển'),
                                  );
                                }
                                return LayoutBuilder(
                                  builder: (ctx, constraints) {
                                    final isWide = constraints.maxWidth >= 900;
                                    final cross = isWide ? 2 : 1;
                                    return GridView.builder(
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: cross,
                                            childAspectRatio: isWide
                                                ? 2.8
                                                : 2.2,
                                            crossAxisSpacing: 16,
                                            mainAxisSpacing: 16,
                                          ),
                                      padding: const EdgeInsets.all(16),
                                      itemCount: jobs2.length,
                                      itemBuilder: (context, index) {
                                        final job = jobs2[index];
                                        return _JobCard(
                                          job: job,
                                          api: _api,
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => JobDetailScreen(
                                                  jobId: job.id,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            )
                          : LayoutBuilder(
                              builder: (ctx, constraints) {
                                final isWide = constraints.maxWidth >= 900;
                                final cross = isWide ? 2 : 1;
                                final filtered = jobs.where((j) {
                                  final locOk =
                                      _filterLocation == null ||
                                      j.location.toLowerCase().contains(
                                        (_filterLocation ?? '').toLowerCase(),
                                      );
                                  final compOk =
                                      _filterCompany == null ||
                                      j.company.toLowerCase().contains(
                                        (_filterCompany ?? '').toLowerCase(),
                                      );
                                  final fromVal =
                                      j.salaryFrom ?? j.salaryTo ?? 0;
                                  final toVal = j.salaryTo ?? j.salaryFrom ?? 0;
                                  final minOk =
                                      _minSalary == null ||
                                      j.isNegotiable ||
                                      fromVal >= (_minSalary ?? 0);
                                  final maxOk =
                                      _maxSalary == null ||
                                      j.isNegotiable ||
                                      (toVal == 0
                                          ? true
                                          : toVal <= (_maxSalary ?? toVal));
                                  return locOk && compOk && minOk && maxOk;
                                }).toList();
                                return GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: cross,
                                        childAspectRatio: isWide ? 2.8 : 2.2,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final job = filtered[index];
                                    return _JobCard(
                                      job: job,
                                      api: _api,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                JobDetailScreen(jobId: job.id),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          const Spacer(),
                          Text(
                            _showHiring
                                ? 'Đang tuyển'
                                : 'Tổng: $filteredCount việc',
                          ),
                        ],
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
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Bộ lọc nâng cao',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Thành phố/Địa điểm'),
                const SizedBox(height: 6),
                TextField(
                  controller: _locationCtl,
                  decoration: const InputDecoration(
                    hintText: 'VD: HANOI, DANANG, HOCHIMINH',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Công ty'),
                const SizedBox(height: 6),
                TextField(
                  controller: _companyCtl,
                  decoration: const InputDecoration(
                    hintText: 'VD: Viettel, VNG, FPT',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Mức lương (VND)'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minSalaryCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Tối thiểu',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxSalaryCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Tối đa'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
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
                          _page = 1;
                          if ((_query ?? '').isNotEmpty) {
                            _futureSearch = _api.searchJobs(
                              q: _query!,
                              page: _page,
                              size: _pageSize,
                              location: _filterLocation,
                              company: _filterCompany,
                              minSalary: _minSalary,
                              maxSalary: _maxSalary,
                            );
                          }
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Xóa bộ lọc'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterLocation = _locationCtl.text.trim().isEmpty
                              ? null
                              : _locationCtl.text.trim();
                          _filterCompany = _companyCtl.text.trim().isEmpty
                              ? null
                              : _companyCtl.text.trim();
                          _minSalary = _minSalaryCtl.text.trim().isEmpty
                              ? null
                              : int.tryParse(_minSalaryCtl.text.trim());
                          _maxSalary = _maxSalaryCtl.text.trim().isEmpty
                              ? null
                              : int.tryParse(_maxSalaryCtl.text.trim());
                          _page = 1;
                          if ((_query ?? '').isNotEmpty) {
                            _futureSearch = _api.searchJobs(
                              q: _query!,
                              page: _page,
                              size: _pageSize,
                              minSalary: _minSalary,
                              maxSalary: _maxSalary,
                            );
                          }
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

  void _openHiringList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Danh sách công việc đang tuyển')),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              SizedBox(
                height: 320,
                child: FutureBuilder<List<Job>>(
                  future: _api.getJobs(page: 1, pageSize: 10),
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
                    final jobs = snapshot.data ?? const <Job>[];
                    if (jobs.isEmpty) {
                      return const Center(
                        child: Text('Chưa có công việc đang tuyển'),
                      );
                    }
                    return ListView.separated(
                      itemCount: jobs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final j = jobs[index];
                        return ListTile(
                          leading: const Icon(Icons.work_outline),
                          title: Text(j.title),
                          subtitle: Text(
                            [
                              j.company,
                              j.location,
                            ].where((e) => e.isNotEmpty).join(' • '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => JobDetailScreen(jobId: j.id),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Inline filters hiển thị ngay trên trang Việc làm
  Widget _buildInlineFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bộ lọc', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _locationCtl,
                      decoration: const InputDecoration(
                        labelText: 'Địa điểm',
                        hintText: 'VD: HANOI, DANANG',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _companyCtl,
                      decoration: const InputDecoration(
                        labelText: 'Công ty',
                        hintText: 'VD: Viettel, VNG',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minSalaryCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Lương tối thiểu (VND)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxSalaryCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Lương tối đa (VND)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(
                    onPressed: _clearInlineFilters,
                    child: const Text('Xóa'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _applyInlineFilters,
                    child: const Text('Áp dụng'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyInlineFilters() {
    setState(() {
      _filterLocation = _locationCtl.text.trim().isEmpty
          ? null
          : _locationCtl.text.trim();
      _filterCompany = _companyCtl.text.trim().isEmpty
          ? null
          : _companyCtl.text.trim();
      _minSalary = _minSalaryCtl.text.trim().isEmpty
          ? null
          : int.tryParse(_minSalaryCtl.text.trim());
      _maxSalary = _maxSalaryCtl.text.trim().isEmpty
          ? null
          : int.tryParse(_maxSalaryCtl.text.trim());
      _page = 1;
      if ((_query ?? '').isNotEmpty) {
        _futureSearch = _api.searchJobs(
          q: _query!,
          page: _page,
          size: _pageSize,
          location: _filterLocation,
          company: _filterCompany,
          minSalary: _minSalary,
          maxSalary: _maxSalary,
        );
      }
    });
  }

  void _clearInlineFilters() {
    setState(() {
      _filterLocation = null;
      _filterCompany = null;
      _minSalary = null;
      _maxSalary = null;
      _locationCtl.clear();
      _companyCtl.clear();
      _minSalaryCtl.clear();
      _maxSalaryCtl.clear();
      _page = 1;
      if ((_query ?? '').isNotEmpty) {
        _futureSearch = _api.searchJobs(
          q: _query!,
          page: _page,
          size: _pageSize,
          location: _filterLocation,
          company: _filterCompany,
          minSalary: _minSalary,
          maxSalary: _maxSalary,
        );
      }
    });
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
                width: 100,
                height: 80,
                child: _CompanyLogo(logo: logo, company: job.company),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            FormatUtils.formatLocation(job.location),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.bolt, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          FormatUtils.formatSalaryFromTo(
                            job.salaryFrom,
                            job.salaryTo,
                            isNegotiable: job.isNegotiable,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [_SaveStatus(jobId: job.id, api: api)],
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
            Text(
              saved ? 'Đã lưu' : 'Lưu',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
    final initials = company.isNotEmpty
        ? company
              .trim()
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
        : '?';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
