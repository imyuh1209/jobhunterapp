import 'package:flutter/material.dart';

class LayoutAdmin extends StatelessWidget {
  final Widget child;
  const LayoutAdmin({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')), 
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Text('Quản trị', style: TextStyle(fontSize: 20)),
            ),
            _MenuItem(title: 'Dashboard', icon: Icons.dashboard, onTap: () => Navigator.pop(context)),
            _MenuItem(title: 'Công ty', icon: Icons.business, onTap: () {}),
            _MenuItem(title: 'Việc làm', icon: Icons.work_outline, onTap: () {}),
            _MenuItem(title: 'Hồ sơ', icon: Icons.assignment_ind_outlined, onTap: () {}),
            _MenuItem(title: 'Kỹ năng', icon: Icons.psychology_alt_outlined, onTap: () {}),
            _MenuItem(title: 'Vai trò', icon: Icons.admin_panel_settings_outlined, onTap: () {}),
            _MenuItem(title: 'Quyền', icon: Icons.lock_outline, onTap: () {}),
            _MenuItem(title: 'Người dùng', icon: Icons.people_outline, onTap: () {}),
          ],
        ),
      ),
      body: child,
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _MenuItem({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }
}