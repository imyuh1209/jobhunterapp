import 'package:flutter/material.dart';
import '../../widgets/admin/layout_admin.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutAdmin(
      child: Center(
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: const [
            _StatCard(title: 'Người dùng', value: '—'),
            _StatCard(title: 'Công ty', value: '—'),
            _StatCard(title: 'Việc làm', value: '—'),
            _StatCard(title: 'Hồ sơ', value: '—'),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 180,
        height: 120,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.black54)),
              const Spacer(),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}