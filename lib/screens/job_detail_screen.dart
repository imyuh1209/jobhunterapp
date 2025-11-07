import 'package:flutter/material.dart';
import '../utils/format_utils.dart';
import 'company_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

import '../models/job_detail.dart';
import '../services/api_service.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _api = ApiService();
  late Future<JobDetail> _future;
  JobDetail? _job;
  bool _saved = false;
  bool _loadingSave = false;
  bool _applied = false;
  bool _loadingApply = false;
  int _applicantCount = 0;

  String _fmtDate(String raw) {
    try {
      if (raw.isEmpty) return '—';
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;
      final d = dt.toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      return '${two(d.day)}/${two(d.month)}/${d.year}';
    } catch (_) {
      return raw;
    }
  }

  String _fmtDateRange(String? start, String? end) {
    final s = (start ?? '').trim();
    final e = (end ?? '').trim();
    if (s.isEmpty && e.isEmpty) return '—';
    if (s.isEmpty) return _fmtDate(e);
    if (e.isEmpty) return _fmtDate(s);
    return '${_fmtDate(s)} - ${_fmtDate(e)}';
  }

  String _extractEmail(Map<String, dynamic> acc) {
    String asStr(dynamic v) => v?.toString() ?? '';
    String pick(dynamic v) {
      final s = asStr(v).trim();
      return s.isNotEmpty ? s : '';
    }

    final user = acc['user'];
    final data = acc['data'];
    final candidates = <String>[
      pick(acc['email']),
      pick(acc['username']),
      if (user is Map) pick(user['email']),
      if (user is Map) pick(user['username']),
      if (data is Map) pick(data['email']),
      if (data is Map) pick(data['username']),
      if (data is Map && data['user'] is Map)
        pick((data['user'] as Map)['email']),
      if (data is Map && data['user'] is Map)
        pick((data['user'] as Map)['username']),
    ];
    for (final c in candidates) {
      if (c.isNotEmpty) return c;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _future = _api.getJobDetail(widget.jobId);
    _future.then((j) {
      if (!mounted) return;
      setState(() {
        _job = j;
        _saved = j.saved;
        _applied = j.applied;
        _applicantCount = j.applicantCount;
      });
    });
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

  Future<void> _apply() async {
    if (_loadingApply || _applied) return;
    await _showApplySheet();
  }

  Future<void> _showApplySheet() async {
    // Lấy email từ tài khoản để hiển thị (read-only)
    String emailValue = '';
    try {
      final acc = await _api.getAccount();
      if (acc is Map<String, dynamic>) {
        emailValue = _extractEmail(acc);
      }
    } catch (_) {}
    Uint8List? pickedBytes;
    String? pickedName;
    String? pickedError;
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setStateSheet) {
              Future<void> pickFile() async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: const ['pdf', 'doc', 'docx'],
                  withData: true,
                );
                final f = result?.files.first;
                if (f != null) {
                  // Giới hạn kích thước < 5MB
                  final max = 5 * 1024 * 1024;
                  if ((f.size ?? 0) > max) {
                    setStateSheet(() {
                      pickedError = 'Kích thước file vượt quá 5MB';
                      pickedBytes = null;
                      pickedName = null;
                    });
                  } else {
                    setStateSheet(() {
                      pickedError = null;
                      pickedBytes = f.bytes;
                      pickedName = f.name;
                    });
                  }
                }
              }

              Future<void> submit() async {
                if (submitting) return;
                setStateSheet(() => submitting = true);
                try {
                  // Kiểm tra trùng lặp
                  final existed = await _api.hasAppliedJob(widget.jobId);
                  if (existed) {
                    throw Exception('Bạn đã ứng tuyển công việc này');
                  }
                  if (pickedBytes == null || pickedName == null) {
                    throw Exception('Vui lòng chọn file CV trước khi gửi');
                  }
                  final fileName = await _api.uploadCvBytes(
                    pickedBytes!,
                    pickedName!,
                  );
                  if (fileName.isEmpty) {
                    throw Exception('Upload CV thất bại');
                  }
                  // Lưu 'url' đúng chuẩn backend: chỉ fileName
                  await _api.applyResumeForJob(
                    jobId: widget.jobId,
                    url: fileName,
                    status: 'PENDING',
                    email: emailValue.isNotEmpty ? emailValue : null,
                  );
                  if (!mounted) return;
                  setState(() {
                    _applied = true;
                  });
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ứng tuyển thành công')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  setStateSheet(() => submitting = false);
                }
              }

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header với nút đóng giống modal mẫu
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ứng Tuyển Job',
                            style: Theme.of(ctx).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Bạn đang ứng tuyển công việc ${_job?.title ?? ''} tại ${_job?.company.name ?? ''}',
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: (_job?.company.logo ?? '').isNotEmpty
                              ? NetworkImage(_job!.company.logo)
                              : null,
                          child: (_job?.company.logo ?? '').isEmpty
                              ? const Icon(Icons.business)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_job?.company.name ?? ''),
                              if ((_job?.location ?? '').isNotEmpty)
                                Text(
                                  'Địa điểm: ${FormatUtils.formatLocation(_job?.location ?? '')}',
                                  style: Theme.of(ctx).textTheme.bodySmall,
                                ),
                              Text(
                                'Lương: ${FormatUtils.formatSalaryFromTo(_job?.salaryFrom, _job?.salaryTo, isNegotiable: _job?.isNegotiable ?? false)}',
                                style: Theme.of(ctx).textTheme.bodySmall,
                              ),
                              Text(
                                'Thời gian: ${_fmtDateRange(_job?.startDate, _job?.endDate)}',
                                style: Theme.of(ctx).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Email'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: emailValue),
                      readOnly: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text('Upload file CV'),
                    const SizedBox(height: 6),
                    // Ô đầu vào dạng TextField nhưng click được để chọn file
                    InkWell(
                      onTap: submitting ? null : pickFile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(ctx).inputDecorationTheme.filled == true
                              ? Theme.of(ctx).inputDecorationTheme.fillColor
                              : null,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Theme.of(ctx).dividerColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.upload_file),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pickedName ??
                                    'Tải lên CV của bạn ( Hỗ trợ *.doc, *.docx, *.pdf, and < 5MB )',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(ctx).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (pickedError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        pickedError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        onPressed:
                            (submitting ||
                                emailValue.trim().isEmpty ||
                                pickedBytes == null)
                            ? null
                            : submit,
                        child: submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Rải CV Nào'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: (_loadingApply || _applied) ? null : _apply,
            icon: _loadingApply
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_applied ? 'Đã ứng tuyển' : 'Ứng tuyển'),
          ),
        ),
      ),
      body: FutureBuilder<JobDetail>(
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
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final details = _JobDetailsSection(
                  title: job.title,
                  company: job.company.name,
                  location: job.location,
                  salary: FormatUtils.formatSalaryFromTo(
                    job.salaryFrom,
                    job.salaryTo,
                    isNegotiable: job.isNegotiable,
                  ),
                  applicantCount: _applicantCount,
                  description: job.description,
                  onApply: (_loadingApply || _applied) ? null : _apply,
                );
                final companyPanel = _CompanyPanel(
                  logo: job.company.logo,
                  company: job.company.name,
                  onApply: (_loadingApply || _applied) ? null : _apply,
                  onOpenCompany: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CompanyScreen(
                          companyName: job.company.name,
                          logoUrl: job.company.logo,
                        ),
                      ),
                    );
                  },
                );
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: details),
                      const SizedBox(width: 24),
                      SizedBox(width: 340, child: companyPanel),
                    ],
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      details,
                      const SizedBox(height: 16),
                      companyPanel,
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  final String company;
  const _FallbackAvatar({super.key, required this.company});

  @override
  Widget build(BuildContext context) {
    final String letter = (company.isNotEmpty ? company.trim()[0] : '?')
        .toUpperCase();
    return Container(
      width: 120,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 48,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _JobDetailsSection extends StatelessWidget {
  final String title;
  final String company;
  final String location;
  final String salary;
  final int applicantCount;
  final String description;
  final VoidCallback? onApply;
  const _JobDetailsSection({
    required this.title,
    required this.company,
    required this.location,
    required this.salary,
    required this.applicantCount,
    required this.description,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onApply,
                  icon: const Icon(Icons.bolt),
                  label: const Text('Ứng tuyển ngay'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.bolt, size: 18),
                const SizedBox(width: 6),
                Text(FormatUtils.formatSalaryRange(salary)),
                const SizedBox(width: 16),
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    FormatUtils.formatLocation(location),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (applicantCount > 0)
              Text(
                'Ứng viên: $applicantCount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            Text(description),
          ],
        ),
      ),
    );
  }
}

class _CompanyPanel extends StatelessWidget {
  final String logo;
  final String company;
  final VoidCallback? onApply;
  final VoidCallback onOpenCompany;
  const _CompanyPanel({
    required this.logo,
    required this.company,
    required this.onApply,
    required this.onOpenCompany,
  });

  @override
  Widget build(BuildContext context) {
    Widget logoWidget;
    if (logo.isNotEmpty) {
      logoWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          logo,
          height: 160,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _FallbackAvatar(company: company),
        ),
      );
    } else {
      logoWidget = Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          company.isNotEmpty ? company[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 48,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 120, child: Center(child: logoWidget)),
            const SizedBox(height: 12),
            Text(
              company,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Nhà tuyển dụng',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onApply,
              child: const Text('Ứng tuyển ngay'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onOpenCompany,
              child: const Text('Xem trang công ty'),
            ),
          ],
        ),
      ),
    );
  }
}
