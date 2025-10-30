import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'screens/jobs_list_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JobHunter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const _HomeDecider(),
    );
  }
}

class _HomeDecider extends StatefulWidget {
  const _HomeDecider();

  @override
  State<_HomeDecider> createState() => _HomeDeciderState();
}

class _HomeDeciderState extends State<_HomeDecider> {
  late Future<bool> _hasToken;

  @override
  void initState() {
    super.initState();
    _hasToken = _checkToken();
  }

  Future<bool> _checkToken() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'accessToken');
    return token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasToken,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final loggedIn = snapshot.data == true;
        return loggedIn ? const JobsListScreen() : const LoginScreen();
      },
    );
  }
}
