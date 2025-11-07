import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

class HeaderAppBar extends StatefulWidget implements PreferredSizeWidget {
  final void Function(String category) onSearch;
  final VoidCallback? onOpenAdmin;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenSavedJobs;
  final VoidCallback? onOpenMyResumes;
  final VoidCallback? onLogout;
  final bool showAdmin;

  const HeaderAppBar({
    super.key,
    required this.onSearch,
    this.onOpenAdmin,
    this.onOpenAccount,
    this.onOpenSavedJobs,
    this.onOpenMyResumes,
    this.onLogout,
    this.showAdmin = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<HeaderAppBar> createState() => _HeaderAppBarState();
}

class _HeaderAppBarState extends State<HeaderAppBar> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 8,
      title: Row(
        children: [
          // Hiển thị logo web tĩnh từ thư mục web
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              '/logoweb.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.work_outline),
            ),
          ),
          const SizedBox(width: 8),
          const Text('JobHunter'),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm việc theo từ khóa, địa điểm, công ty',
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant,
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Xóa',
                        onPressed: () {
                          _controller.clear();
                          widget.onSearch('');
                        },
                        icon: const Icon(Icons.close),
                      ),
                    IconButton(
                      tooltip: 'Tìm kiếm',
                      onPressed: () {
                        widget.onSearch(_controller.text.trim());
                      },
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
              ),
              onSubmitted: (value) {
                widget.onSearch(value.trim());
              },
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Bật/tắt Dark Mode',
          icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode),
          onPressed: () {
            ThemeProvider.of(context).toggle();
          },
        ),
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
              case 'myresumes':
                widget.onOpenMyResumes?.call();
                break;
              case 'logout':
                widget.onLogout?.call();
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'account', child: Text('Tài khoản')),
            if (widget.showAdmin)
              const PopupMenuItem(value: 'admin', child: Text('Trang quản trị')),
            const PopupMenuItem(value: 'saved', child: Text('Công việc đã lưu')),
            const PopupMenuItem(value: 'myresumes', child: Text('Hồ sơ đã ứng tuyển')),
            const PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
          ],
        ),
      ],
    );
  }
}