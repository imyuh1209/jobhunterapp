import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_service.dart';
import 'login_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();
  late Future<Map<String, String?>> _tokensFuture;

  @override
  void initState() {
    super.initState();
    _tokensFuture = _readTokens();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: FutureBuilder<Map<String, String?>>(
        future: _tokensFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? {'access': null, 'refresh': null};
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thông tin xác thực', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _InfoRow(label: 'Access token', value: _mask(data['access'])),
                _InfoRow(label: 'Refresh token', value: _mask(data['refresh'])),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Đăng xuất'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _storage.delete(key: 'accessToken');
                        await _storage.delete(key: 'refreshToken');
                        setState(() {
                          _tokensFuture = _readTokens();
                        });
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Xóa token cục bộ'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Cài đặt tài khoản', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                const Text('Chức năng cập nhật thông tin/đổi mật khẩu sẽ được bổ sung.'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}