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
  final _companyCtl = TextEditingController();
  String _gender = 'Nam';
  String _email = '';

  // Lịch sử ứng tuyển
  late Future<List<Resume>> _resumesFuture;

  // Nhận jobs qua email
  bool _subscribeJobs = false;
  final _categoriesCtl = TextEditingController();
  final _emailSubCtl = TextEditingController();
  List<Map<String, String>> _skillOptions = const [];
  Set<String> _selectedSkillIds = {};
  String? _subscriberId; // để biết create/update

  @override
  void initState() {
    super.initState();
    _tokensFuture = _readTokens();
    _loadAccountPrefill();
    _resumesFuture = _api.getMyResumes();
    _initSubscriberFlow();
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
      // Ưu tiên /api/v1/users/me; nếu trống hoặc lỗi, fallback /api/v1/auth/account
      Map<String, dynamic> acc = {};
      try {
        acc = await _api.getUserMe();
      } catch (_) {}
      bool emptyAcc = acc.isEmpty || (
        (acc['email'] == null || acc['email'].toString().isEmpty) &&
        (acc['name'] == null || acc['name'].toString().isEmpty)
      );
      if (emptyAcc) {
        try {
          acc = await _api.getAccount();
        } catch (_) {}
      }

      final name = acc['name'] ?? acc['fullName'] ?? acc['username'] ?? acc['displayName'];
      final email = acc['email'] ?? acc['username'];
      final genderRaw = acc['gender'] ?? acc['sex'];
      final address = acc['address'] ?? acc['location'];
      final company = acc['company'] ?? acc['companyName'];
      final ageRaw = acc['age'];
      // Map backend gender enum to VN labels
      final gender = () {
        final g = (genderRaw?.toString() ?? '').toUpperCase();
        if (g == 'MALE') return 'Nam';
        if (g == 'FEMALE') return 'Nữ';
        if (['OTHER','UNKNOWN','KHAC'].contains(g)) return 'Khác';
        return genderRaw?.toString();
      }();
      setState(() {
        _nameCtl.text = (name?.toString() ?? '').trim();
        _email = email?.toString() ?? '';
        _gender = ['Nam', 'Nữ', 'Khác'].contains(gender) ? gender! : (_gender);
        _addressCtl.text = (address?.toString() ?? '').trim();
        _companyCtl.text = (company?.toString() ?? '').trim();
        _ageCtl.text = ageRaw?.toString() ?? '';
      });
      // Đồng bộ email vào tab Email nếu chưa có giá trị
      if ((_emailSubCtl.text).isEmpty && _email.isNotEmpty) {
        _emailSubCtl.text = _email;
      }
      // Overlay bởi dữ liệu đã lưu cục bộ (nếu có)
      final savedName = await _storage.read(key: 'profile_name');
      final savedAge = await _storage.read(key: 'profile_age');
      final savedGender = await _storage.read(key: 'profile_gender');
      final savedAddr = await _storage.read(key: 'profile_address');
      final savedCompany = await _storage.read(key: 'profile_company');
      setState(() {
        if ((savedName ?? '').isNotEmpty) _nameCtl.text = savedName!;
        if ((savedAge ?? '').isNotEmpty) _ageCtl.text = savedAge!;
        if ((savedGender ?? '').isNotEmpty) _gender = savedGender!;
        if ((savedAddr ?? '').isNotEmpty) _addressCtl.text = savedAddr!;
        if ((savedCompany ?? '').isNotEmpty) _companyCtl.text = savedCompany!;
      });
    } catch (_) {
      // fallback từ local nếu không lấy được acc
      final savedName = await _storage.read(key: 'profile_name');
      final savedAge = await _storage.read(key: 'profile_age');
      final savedGender = await _storage.read(key: 'profile_gender');
      final savedAddr = await _storage.read(key: 'profile_address');
      final savedCompany = await _storage.read(key: 'profile_company');
      setState(() {
        _nameCtl.text = savedName ?? '';
        _ageCtl.text = savedAge ?? '';
        _gender = savedGender ?? 'Nam';
        _addressCtl.text = savedAddr ?? '';
        _companyCtl.text = savedCompany ?? '';
      });
    }
  }

  Future<void> _saveProfileLocally() async {
    await _storage.write(key: 'profile_name', value: _nameCtl.text.trim());
    await _storage.write(key: 'profile_age', value: _ageCtl.text.trim());
    await _storage.write(key: 'profile_gender', value: _gender);
    await _storage.write(key: 'profile_address', value: _addressCtl.text.trim());
    await _storage.write(key: 'profile_company', value: _companyCtl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật thông tin cục bộ')));
  }

  // Bỏ lưu local cho email subscription; dùng hoàn toàn dữ liệu backend

  Future<void> _initSubscriberFlow() async {
    try {
      final skills = await _api.fetchSkills(page: 1, size: 100);
      setState(() {
        _skillOptions = skills.map((e) => {'id': e['id']?.toString() ?? '', 'name': e['name']?.toString() ?? ''}).toList();
      });
    } catch (_) {}
    try {
      final sub = await _api.getSubscriber();
      if (sub != null) {
        setState(() {
          _subscriberId = sub.id.isNotEmpty ? sub.id : null;
          _subscribeJobs = true;
          _emailSubCtl.text = sub.email;
          final ids = sub.skills.map((s) => s.id).where((id) => id.isNotEmpty).toSet();
          if (ids.isNotEmpty) {
            _selectedSkillIds = ids;
          } else {
            // fallback by name
            final nameToId = {for (final o in _skillOptions) o['name']!: o['id']!};
            _selectedSkillIds = sub.skills.map((s) => nameToId[s.name]).whereType<String>().toSet();
          }
        });
      }
    } catch (_) {}
  }

  // Không còn lưu cục bộ email subscription

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
    _companyCtl.dispose();
    _categoriesCtl.dispose();
    _emailSubCtl.dispose();
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
              Tab(text: 'Đổi mật khẩu'),
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
            _buildChangePasswordTab(),
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
            child: ElevatedButton(onPressed: _saveProfileToBackend, child: const Text('Cập nhật')),
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
                  if ((r.companyName ?? '').isNotEmpty) Text('Công ty: ${r.companyName}'),
                  if (r.createdAt != null)
                    Text(
                      'Ngày nộp: ${r.createdAt!.toLocal().day}/${r.createdAt!.toLocal().month}/${r.createdAt!.toLocal().year} ${r.createdAt!.toLocal().hour.toString().padLeft(2, '0')}:${r.createdAt!.toLocal().minute.toString().padLeft(2, '0')}',
                    ),
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
            onChanged: _toggleSubscribeJobs,
            title: const Text('Nhận thông báo việc phù hợp qua email'),
            subtitle: const Text('Gửi định kỳ theo danh mục bạn chọn'),
          ),
          if (!_subscribeJobs && _subscriberId == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Chưa đăng ký nhận jobs qua email. Bật công tắc hoặc nhấn "Cập nhật" để tạo đăng ký.',
              ),
            ),
          const SizedBox(height: 8),
          _LabeledField(
            label: 'Email nhận việc',
            child: TextField(
              controller: _emailSubCtl,
              readOnly: true,
              decoration: const InputDecoration(hintText: 'Sử dụng email tài khoản'),
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Kỹ năng quan tâm',
            child: Wrap(
              spacing: 8,
              runSpacing: -8,
              children: _skillOptions.map((opt) {
                final id = opt['id'] ?? '';
                final name = opt['name'] ?? id;
                final selected = _selectedSkillIds.contains(id);
                return FilterChip(
                  label: Text(name),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedSkillIds.add(id);
                      } else {
                        _selectedSkillIds.remove(id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ElevatedButton(onPressed: _saveSubscriberToServer, child: const Text('Cập nhật')),
          ),
        ],
      ),
    );
  }

  // Đổi mật khẩu
  final _currentPwdCtl = TextEditingController();
  final _newPwdCtl = TextEditingController();

  Widget _buildChangePasswordTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabeledField(
            label: 'Mật khẩu hiện tại',
            child: TextField(controller: _currentPwdCtl, obscureText: true, decoration: const InputDecoration(hintText: 'Nhập mật khẩu hiện tại')),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Mật khẩu mới',
            child: TextField(controller: _newPwdCtl, obscureText: true, decoration: const InputDecoration(hintText: 'Nhập mật khẩu mới')),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () async {
                final cur = _currentPwdCtl.text.trim();
                final neu = _newPwdCtl.text.trim();
                if (cur.isEmpty || neu.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đủ mật khẩu')));
                  return;
                }
                try {
                  await _api.changePassword(currentPassword: cur, newPassword: neu);
                  _currentPwdCtl.clear();
                  _newPwdCtl.clear();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công')));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                }
              },
              child: const Text('Đổi mật khẩu'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSubscriberToServer() async {
    try {
      if (!_subscribeJobs) {
        // Nếu tắt, hủy đăng ký trên server
        if (_subscriberId != null) {
          await _api.deleteSubscriber(_subscriberId!);
        }
        setState(() {
          _subscriberId = null;
          _selectedSkillIds.clear();
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tắt nhận job qua email')));
        return;
      }
      final email = _emailSubCtl.text.trim();
      if (email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập email')));
        return;
      }
      final ids = _selectedSkillIds.map((e) => int.tryParse(e)).whereType<int>().toList();
      if (ids.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ít nhất một kỹ năng')));
        return;
      }
      if (_subscriberId == null) {
        final created = await _api.createSubscriber(email: email, name: _nameCtl.text.trim(), skillIds: ids);
        setState(() => _subscriberId = created.id.isNotEmpty ? created.id : null);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đăng ký nhận job qua email')));
      } else {
        await _api.updateSubscriber(id: _subscriberId!, email: email, name: _nameCtl.text.trim(), skillIds: ids);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật thông tin nhận job')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  void _toggleSubscribeJobs(bool v) async {
    setState(() => _subscribeJobs = v);
    if (!v) {
      // tắt ngay khi gạt công tắc
      try {
        if (_subscriberId != null) {
          await _api.deleteSubscriber(_subscriberId!);
        }
        setState(() {
          _subscriberId = null;
          _selectedSkillIds.clear();
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tắt nhận job qua email')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _saveProfileToBackend() async {
    try {
      final name = _nameCtl.text.trim();
      final address = _addressCtl.text.trim();
      // Map VN label back to backend enum
      String? genderCode;
      switch (_gender) {
        case 'Nam':
          genderCode = 'MALE';
          break;
        case 'Nữ':
          genderCode = 'FEMALE';
          break;
        case 'Khác':
          genderCode = 'OTHER';
          break;
        default:
          genderCode = null;
      }
      await _api.updateUser(
        name: name.isNotEmpty ? name : null,
        address: address.isNotEmpty ? address : null,
        gender: genderCode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ trên hệ thống')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
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