import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/company_brief.dart';
import 'company_screen.dart';

class CompaniesListScreen extends StatefulWidget {
  const CompaniesListScreen({super.key});

  @override
  State<CompaniesListScreen> createState() => _CompaniesListScreenState();
}

class _CompaniesListScreenState extends State<CompaniesListScreen> {
  final _api = ApiService();
  late Future<List<CompanyBrief>> _future;
  bool _loggedOnce = false;

  @override
  void initState() {
    super.initState();
    _future = _api.getTopCompanies(page: 1, size: 8);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Công ty tuyển dụng')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _api.getTopCompanies(page: 1, size: 8));
          _loggedOnce = false;
        },
        child: FutureBuilder<List<CompanyBrief>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final friendly = 'Không thể tải danh sách công ty. Vui lòng kiểm tra kết nối và thử lại.';
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(friendly, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _future = _api.getTopCompanies(page: 1, size: 8));
                        _loggedOnce = false;
                      },
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              );
            }
            final companies = snapshot.data ?? const <CompanyBrief>[];
            if (!_loggedOnce && companies.isNotEmpty) {
              for (final c in companies) {
                // Log thủ công URL ảnh để xác nhận đúng base + đường dẫn tương đối
                debugPrint('[COMPANY] id='+c.id+' name='+c.name+' logo='+c.logo);
              }
              _loggedOnce = true;
            }
            if (companies.isEmpty) {
              return const Center(child: Text('Chưa có dữ liệu công ty'));
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 3 / 2,
              ),
              itemCount: companies.length,
              itemBuilder: (context, index) {
                final c = companies[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CompanyScreen(
                            companyName: c.name,
                            logoUrl: c.logo,
                            companyId: c.id,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                c.logo,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(Icons.business, size: 40, color: Theme.of(context).colorScheme.secondary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}