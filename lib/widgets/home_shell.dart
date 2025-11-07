import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/jobs_list_screen.dart';
import '../screens/saved_jobs_screen.dart';
import '../screens/companies_list_screen.dart';
import '../screens/account_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    HomeScreen(),
    JobsListScreen(),
    CompaniesListScreen(),
    SavedJobsScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.work_outline), label: 'Việc làm'),
          NavigationDestination(icon: Icon(Icons.business_outlined), label: 'Công ty'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), label: 'Đã lưu'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Tài khoản'),
        ],
      ),
    );
  }
}