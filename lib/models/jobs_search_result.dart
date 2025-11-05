import '../models/job.dart';

class JobsSearchResult {
  final List<Job> items;
  final int page; // 1-based
  final int pageSize;
  final int pages;
  final int total;

  JobsSearchResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.pages,
    required this.total,
  });
}