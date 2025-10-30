class SavedJob {
  final String savedId;
  final String jobId;
  final String title;
  final String company;
  final String location;

  SavedJob({
    required this.savedId,
    required this.jobId,
    required this.title,
    required this.company,
    required this.location,
  });

  static String _asString(dynamic v) {
    try {
      if (v == null) return '';
      if (v is String) return v;
      if (v is num || v is bool) return v.toString();
      if (v is Map) {
        final m = v;
        final name = m['name'] ?? m['title'] ?? m['label'] ?? m['companyName'];
        return name?.toString() ?? v.toString();
      }
      if (v is List) return v.join(', ');
      return v.toString();
    } catch (_) {
      return '';
    }
  }

  factory SavedJob.fromJson(Map<String, dynamic> json) {
    // Flexible shapes: {id, jobId, job:{id,title,company,location}}
    final savedId = _asString(json['id'] ?? json['savedId']);
    String jobId = _asString(json['jobId']);
    String title = _asString(json['title']);
    String company = _asString(json['company']);
    String location = _asString(json['location']);
    final job = json['job'];
    if (job is Map<String, dynamic>) {
      jobId = jobId.isNotEmpty ? jobId : _asString(job['id']);
      title = title.isNotEmpty ? title : _asString(job['title']);
      company = company.isNotEmpty ? company : _asString(job['company']);
      location = location.isNotEmpty ? location : _asString(job['location']);
    }
    return SavedJob(
      savedId: savedId,
      jobId: jobId,
      title: title,
      company: company,
      location: location,
    );
  }
}