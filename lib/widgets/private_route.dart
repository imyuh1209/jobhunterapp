import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../screens/login_screen.dart';

class PrivateRoute extends StatelessWidget {
  final Widget Function(BuildContext) builder;
  const PrivateRoute({super.key, required this.builder});

  Future<bool> _hasToken() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'accessToken');
    return token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
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
}