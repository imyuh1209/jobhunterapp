import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/home_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  String? _gender; // 'MALE' | 'FEMALE' | 'OTHER'
  bool _remember = true;
  final _api = ApiService();

  bool _loading = false;
  String? _error;
  bool _showPassword = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _confirmCtl.dispose();
    _addressCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtl.text.trim();
    final password = _passwordCtl.text;
    final name = _nameCtl.text.trim();
    final address = _addressCtl.text.trim();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _api.register(
        email: email,
        password: password,
        name: name.isNotEmpty ? name : null,
        gender: _gender,
        address: address.isNotEmpty ? address : null,
      );
      await _api.login(email: email, password: password, remember: _remember);
      if ((_gender ?? '').isNotEmpty ||
          address.isNotEmpty ||
          name.isNotEmpty) {
        try {
          await _api.updateUser(
            name: name.isNotEmpty ? name : null,
            gender: _gender,
            address: address.isNotEmpty ? address : null,
          );
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    } catch (e) {
      // Phân loại thông báo lỗi body theo status code
      final msg = e.toString();
      String ui;
      if (msg.contains('401')) {
        ui = '401 - Token không hợp lệ hoặc có Authorization không cần thiết. Vui lòng thử lại.';
      } else if (msg.contains('400')) {
        ui = '400 - Dữ liệu không hợp lệ hoặc email đã tồn tại.';
      } else {
        ui = msg;
      }
      setState(() => _error = ui);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký tài khoản')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtl,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Vui lòng nhập họ và tên';
                  if (v.trim().length < 2) return 'Họ và tên quá ngắn';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Vui lòng nhập email';
                  final emailRe = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
                  if (!emailRe.hasMatch(value)) return 'Email không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtl,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
                obscureText: !_showPassword,
                validator: (v) {
                  final value = v ?? '';
                  if (value.isEmpty) return 'Vui lòng nhập mật khẩu';
                  if (value.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                  final hasUpper = RegExp(r'[A-Z]').hasMatch(value);
                  final hasLower = RegExp(r'[a-z]').hasMatch(value);
                  final hasDigit = RegExp(r'\d').hasMatch(value);
                  final hasSpecial = RegExp(
                    r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\/;+]',
                  ).hasMatch(value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtl,
                decoration: InputDecoration(
                  labelText: 'Xác nhận mật khẩu',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  ),
                ),
                obscureText: !_showConfirm,
                validator: (v) {
                  final value = v ?? '';
                  if (value.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                  if (value != _passwordCtl.text)
                    return 'Xác nhận mật khẩu không khớp';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Giới tính'),
                items: const [
                  DropdownMenuItem(value: 'MALE', child: Text('Nam')),
                  DropdownMenuItem(value: 'FEMALE', child: Text('Nữ')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
                ],
                onChanged: (v) => setState(() => _gender = v),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vui lòng chọn giới tính';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtl,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ (tuỳ chọn)',
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isNotEmpty && value.length < 5)
                    return 'Địa chỉ quá ngắn';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _remember,
                onChanged: (v) => setState(() => _remember = v ?? true),
                title: const Text('Ghi nhớ đăng nhập'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 4),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Đăng ký'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
