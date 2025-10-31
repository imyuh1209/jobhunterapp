import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../screens/login_screen.dart';
import '../services/api_service.dart';

class PrivateRoute extends StatelessWidget {
  final Widget Function(BuildContext) builder;
  final List<String>? allowedRoles;
  const PrivateRoute({super.key, required this.builder, this.allowedRoles});

  Future<bool> _hasToken() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'accessToken');
    return token != null && token.isNotEmpty;
  }

  Future<bool> _hasRequiredRole() async {
    // Nếu không yêu cầu vai trò cụ thể, cho phép.
    if (allowedRoles == null || allowedRoles!.isEmpty) return true;
    try {
      final api = ApiService();
      final acct = await api.getAccount();
      final Set<String> roles = {};
      final r1 = acct['role'];
      final r2 = acct['roles'] ?? acct['authorities'];
      void addRole(dynamic v) {
        if (v is String) {
          roles.add(v.toUpperCase());
        } else if (v is Map<String, dynamic>) {
          final n = v['name'] ?? v['authority'] ?? v['role'];
          if (n is String) roles.add(n.toUpperCase());
        }
      }
      addRole(r1);
      if (r2 is List) {
        for (final e in r2) {
          addRole(e);
        }
      } else if (r2 is String) {
        addRole(r2);
      }
      bool match(String req) {
        final up = req.toUpperCase();
        return roles.contains(up) || roles.contains('ROLE_$up');
      }
      return allowedRoles!.any(match);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nếu không yêu cầu vai trò, chỉ cần kiểm tra token như cũ.
    if (allowedRoles == null || allowedRoles!.isEmpty) {
      return FutureBuilder<bool>(
        future: _hasToken(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final ok = snapshot.data == true;
          return ok ? builder(context) : const LoginScreen();
        },
      );
    }

    // Có yêu cầu vai trò: kiểm tra token trước, sau đó kiểm tra vai trò.
    return FutureBuilder<bool>(
      future: _hasToken(),
      builder: (context, tokenSnap) {
        if (tokenSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final hasToken = tokenSnap.data == true;
        if (!hasToken) return const LoginScreen();
        return FutureBuilder<bool>(
          future: _hasRequiredRole(),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final allowed = roleSnap.data == true;
            if (!allowed) {
              return const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Bạn không có quyền truy cập khu vực này.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }
            return builder(context);
          },
        );
      },
    );
  }
}