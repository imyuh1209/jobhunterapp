import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../models/home_banner.dart';
import '../models/company_brief.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/header_app_bar.dart';
import 'jobs_list_screen.dart';
import 'account_screen.dart';
import 'saved_jobs_screen.dart';
import 'my_resumes_screen.dart';
import '../widgets/private_route.dart';
import 'company_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _current = 0;

  final _api = ApiService();
  List<HomeBanner> _banners = const [];
  // Danh sách công ty lấy từ API
  List<CompanyBrief> _companies = const [];
  bool _companiesLoading = true;
  String? _companiesError;
  final List<String> _fallbackBanners = const [
    '/logoweb.png',
    '/icons/Icon-512.png',
    'https://picsum.photos/seed/jobhunter/900/250',
  ];

  String _resolve(String url) {
    final u = url.trim();
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    if (u.startsWith('/')) return '${ApiConfig.baseUrl}$u';
    return u;
  }

  @override
  void initState() {
    super.initState();
    _loadBanners();
    _loadTopCompanies();
  }

  Future<void> _loadBanners() async {
    try {
      final items = await _api.getHomeBanners();
      // sort by position if available
      items.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
      setState(() {
        _banners = items;
      });
    } catch (e) {
      // Giữ im lặng nếu API lỗi; sẽ dùng fallback
      // Retry một lần nhẹ
      try {
        final retry = await _api.getHomeBanners();
        retry.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
        setState(() {
          _banners = retry;
        });
      } catch (_) {}
    }
  }

  Future<void> _loadTopCompanies() async {
    try {
      final items = await _api.getTopCompanies(page: 1, size: 12);
      setState(() {
        _companies = items;
        _companiesLoading = false;
        _companiesError = null;
      });
    } catch (e) {
      // im lặng, không dùng dữ liệu cứng; chỉ ghi nhận lỗi và tắt loading
      setState(() {
        _companies = const [];
        _companiesLoading = false;
        _companiesError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderAppBar(
        showAdmin: false,
        onSearch: (q) {
          final query = q.trim();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  JobsListScreen(category: query.isEmpty ? null : query),
            ),
          );
        },
        onOpenAccount: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AccountScreen()));
        },
        onOpenSavedJobs: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PrivateRoute(builder: (_) => const SavedJobsScreen()),
            ),
          );
        },
        onOpenMyResumes: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PrivateRoute(builder: (_) => const MyResumesScreen()),
            ),
          );
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner carousel
          AspectRatio(
            aspectRatio: 16 / 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemCount: _banners.isNotEmpty
                        ? _banners.length
                        : _fallbackBanners.length,
                    itemBuilder: (context, index) {
                      final hasData = _banners.isNotEmpty;
                      final imgUrl = hasData
                          ? _resolve(_banners[index].imageUrl)
                          : _resolve(_fallbackBanners[index]);
                      final link = hasData ? (_banners[index].link) : '';
                      Widget image = CachedNetworkImage(
                        imageUrl: imgUrl,
                        fit: BoxFit.cover,
                        placeholder: (ctx, _) => Container(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                        ),
                        errorWidget: (ctx, _, __) => Container(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: Center(
                            child: Text(
                              'Banner ${index + 1}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      );
                      if (hasData && link.isNotEmpty) {
                        image = InkWell(
                          onTap: () async {
                            final uri = Uri.tryParse(link);
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          child: image,
                        );
                      }
                      return image;
                    },
                  ),
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _banners.isNotEmpty
                            ? _banners.length
                            : _fallbackBanners.length,
                        (i) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _current
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Section: Nhà Tuyển Dụng Hàng Đầu
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nhà Tuyển Dụng Hàng Đầu',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const JobsListScreen()),
                  );
                },
                child: const Text('Xem tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (_) {
              if (_companiesLoading) {
                return SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (_companies.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Chưa có dữ liệu nhà tuyển dụng',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }
              return SizedBox(
                height: 260,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _companies.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final data = _companies[index];
                    final name = data.name;
                    final logo = data.logo;
                    return SizedBox(
                      width: 220,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CompanyScreen(
                                  companyName: name,
                                  logoUrl: logo,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceVariant,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: _resolve(logo),
                                        fit: BoxFit.contain,
                                        errorWidget: (_, __, ___) => Center(
                                          child: Text(
                                            name.isNotEmpty ? name[0] : '?',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Khám phá cơ hội việc làm',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Cập nhật việc làm mới nhất và nhiều ưu đãi tuyển dụng từ các công ty hàng đầu.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HomeTile(icon: Icons.work_outline, label: 'Việc làm mới'),
              _HomeTile(icon: Icons.campaign_outlined, label: 'Đang tuyển'),
              _HomeTile(icon: Icons.bookmark_outline, label: 'Đã lưu'),
              _HomeTile(icon: Icons.person_outline, label: 'Tài khoản'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HomeTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
