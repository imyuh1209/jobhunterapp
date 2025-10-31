import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/resume.dart';
import '../services/api_service.dart';
import 'job_detail_screen.dart';
import 'login_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();

  // Tokens (xác thực)
  late Future<Map<String, String?>> _tokensFuture;

  // Thông tin cá nhân
  final _nameCtl = TextEditingController();
  final _ageCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  String _gender = 'Nam';
  String _email = '';

  // Lịch sử ứng tuyển
  late Future<List<Resume>> _resumesFuture;

  // Nhận jobs qua email
  bool _subscribeJobs = false;
  final _categoriesCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tokensFuture = _readTokens();
    _loadAccountPrefill();
    _resumesFuture = _api.getMyResumes();
    _loadEmailSubscription();
  }

  Future<Map<String, String?>> _readTokens() async {
    final access = await _storage.read(key: 'accessToken');
    final refresh = await _storage.read(key: 'refreshToken');
    return {'access': access, 'refresh': refresh};
  }

  String _mask(String? value) {
    if (value == null || value.isEmpty) return '—';
    if (value.length <= 12) return value;
    return '${value.substring(0, 6)}…${value.substring(value.length - 6)}';
  }

  Future<void> _logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _loadAccountPrefill() async {
    try {
      final acc = await _api.getAccount();
      final name = acc['name'] ?? acc['fullName'] ?? acc['username'];
      final email = acc['email'];
      final gender = acc['gender'] ?? acc['sex'];
      final address = acc['address'] ?? acc['location'];
      final ageRaw = acc['age'];
      setState(() {
        _nameCtl.text = (name?.toString() ?? '').trim();
        _email = email?.toString() ?? '';
        _gender = ['Nam', 'Nữ', 'Khác'].contains(gender) ? gender : (_gender);
        _addressCtl.text = (address?.toString() ?? '').trim();
        _ageCtl.text = ageRaw?.toString() ?? '';
      });
      // Overlay bởi dữ liệu đã lưu cục bộ (nếu có)
      final savedName = await _storage.read(key: 'profile_name');
      final savedAge = await _storage.read(key: 'profile_age');
      final savedGender = await _storage.read(key: 'profile_gender');
      final savedAddr = await _storage.read(key: 'profile_address');
      setState(() {
        if ((savedName ?? '').isNotEmpty) _nameCtl.text = savedName!;
        if ((savedAge ?? '').isNotEmpty) _ageCtl.text = savedAge!;
        if ((savedGender ?? '').isNotEmpty) _gender = savedGender!;
        if ((savedAddr ?? '').isNotEmpty) _addressCtl.text = savedAddr!;
      });
    } catch (_) {
      // fallback từ local nếu không lấy được acc
      final savedName = await _storage.read(key: 'profile_name');
      final savedAge = await _storage.read(key: 'profile_age');
      final savedGender = await _storage.read(key: 'profile_gender');
      final savedAddr = await _storage.read(key: 'profile_address');
      setState(() {
        _nameCtl.text = savedName ?? '';
        _ageCtl.text = savedAge ?? '';
        _gender = savedGender ?? 'Nam';
        _addressCtl.text = savedAddr ?? '';
      });
    }
  }

  Future<void> _saveProfileLocally() async {
    await _storage.write(key: 'profile_name', value: _nameCtl.text.trim());
    await _storage.write(key: 'profile_age', value: _ageCtl.text.trim());
    await _storage.write(key: 'profile_gender', value: _gender);
    await _storage.write(key: 'profile_address', value: _addressCtl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật thông tin cục bộ')));
  }

  Future<void> _loadEmailSubscription() async {
    final sub = await _storage.read(key: 'jobs_subscribed');
    final cats = await _storage.read(key: 'jobs_categories');
    setState(() {
      _subscribeJobs = sub == 'true';
      _categoriesCtl.text = cats ?? '';
    });
  }

  Future<void> _saveEmailSubscription() async {
    await _storage.write(key: 'jobs_subscribed', value: _subscribeJobs.toString());
    await _storage.write(key: 'jobs_categories', value: _categoriesCtl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu cài đặt nhận Jobs qua Email')));
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
      case 'ACCEPTED':
        return Colors.green;
      case 'REJECTED':
      case 'DENIED':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _ageCtl.dispose();
    _addressCtl.dispose();
    _categoriesCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý tài khoản'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Thông tin cá nhân'),
              Tab(text: 'Lịch sử ứng tuyển'),
              Tab(text: 'Nhận Jobs qua Email'),
            ],
          ),
          actions: [
            IconButton(onPressed: _logout, tooltip: 'Đăng xuất', icon: const Icon(Icons.logout)),
          ],
        ),
        body: TabBarView(
          children: [
            _buildProfileTab(),
            _buildResumesTab(),
            _buildEmailTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _LabeledField(
            label: 'Tên hiển thị',
            child: TextField(controller: _nameCtl, decoration: const InputDecoration(hintText: 'Nhập tên hiển thị')),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Email',
            child: TextField(readOnly: true, controller: TextEditingController(text: _email), decoration: const InputDecoration()),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Tuổi',
            child: TextField(controller: _ageCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'VD: 21')),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Giới tính',
            child: DropdownButtonFormField<String>(
              value: _gender,
              items: const [
                DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                DropdownMenuItem(value: 'Khác', child: Text('Khác')),
              ],
              onChanged: (v) => setState(() => _gender = v ?? 'Nam'),
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Địa chỉ',
            child: TextField(
              controller: _addressCtl,
              decoration: InputDecoration(suffixIcon: IconButton(onPressed: () => _addressCtl.clear(), icon: const Icon(Icons.close)) ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ElevatedButton(onPressed: _saveProfileLocally, child: const Text('Cập nhật')),
          ),
        ],
      ),
    );
  }

  Widget _buildResumesTab() {
    return FutureBuilder<List<Resume>>(
      future: _resumesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
        }
        final items = snapshot.data ?? const <Resume>[];
        if (items.isEmpty) {
          return const Center(child: Text('Bạn chưa ứng tuyển công việc nào'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = items[i];
            final status = r.status ?? 'PENDING';
            final color = _statusColor(status);
            return ListTile(
              leading: CircleAvatar(backgroundColor: color, child: const Icon(Icons.assignment_turned_in, color: Colors.white)),
              title: Text(r.jobTitle ?? 'Hồ sơ ứng tuyển'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trạng thái: $status'),
                  if ((r.url ?? '').isNotEmpty) Text('CV: ${r.url}'),
                  if ((r.email ?? '').isNotEmpty) Text('Email: ${r.email}'),
                ],
              ),
              onTap: () {
                final jid = r.jobId;
                if (jid != null && jid.isNotEmpty) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: jid)));
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmailTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: _subscribeJobs,
            onChanged: (v) => setState(() => _subscribeJobs = v),
            title: const Text('Nhận thông báo việc phù hợp qua email'),
            subtitle: const Text('Gửi định kỳ theo danh mục bạn chọn'),
          ),
          const SizedBox(height: 8),
          _LabeledField(
            label: 'Danh mục ưu tiên',
            child: TextField(
              controller: _categoriesCtl,
              decoration: const InputDecoration(hintText: 'Ví dụ: Java, Flutter, React'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ElevatedButton(onPressed: _saveEmailSubscription, child: const Text('Cập nhật')),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}