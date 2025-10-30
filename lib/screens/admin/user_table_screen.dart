import 'package:flutter/material.dart';
import '../../widgets/admin/layout_admin.dart';

class UserTableScreen extends StatelessWidget {
  const UserTableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutAdmin(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Danh sách người dùng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Expanded(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Tên')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Vai trò')),
                ],
                rows: const [
                  DataRow(cells: [
                    DataCell(Text('—')),
                    DataCell(Text('—')),
                    DataCell(Text('—')),
                    DataCell(Text('—')),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}