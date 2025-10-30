import 'package:flutter/material.dart';

class HeaderAppBar extends StatefulWidget implements PreferredSizeWidget {
  final void Function(String category) onSearch;
  final VoidCallback? onOpenAdmin;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenSavedJobs;
  final VoidCallback? onLogout;

  const HeaderAppBar({
    super.key,
    required this.onSearch,
    this.onOpenAdmin,
    this.onOpenAccount,
    this.onOpenSavedJobs,
    this.onLogout,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<HeaderAppBar> createState() => _HeaderAppBarState();
}

class _HeaderAppBarState extends State<HeaderAppBar> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 8,
      title: Row(
        children: [
          const Icon(Icons.work_outline),
          const SizedBox(width: 8),
          const Text('JobHunter'),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm danh mục... (ví dụ: Java, React)',
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (value) {
                final v = value.trim();
                if (v.isNotEmpty) widget.onSearch(v);
              },
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'account':
                widget.onOpenAccount?.call();
                break;
              case 'admin':
                widget.onOpenAdmin?.call();
                break;
              case 'saved':
                widget.onOpenSavedJobs?.call();
                break;
              case 'logout':
                widget.onLogout?.call();
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'account', child: Text('Tài khoản')),
            PopupMenuItem(value: 'admin', child: Text('Trang quản trị')),
            PopupMenuItem(value: 'saved', child: Text('Công việc đã lưu')),
            PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
          ],
        ),
      ],
    );
  }
}