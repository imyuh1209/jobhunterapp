class SavedJob {
  final String savedId;
  final String jobId;
  final String title;
  final String company;
  final String location;
  // NEW: company logo for SavedJobDTO
  final String companyLogo;
  // NEW: salary aliases for SavedJobDTO
  final int? salaryFrom;
  final int? salaryTo;
  final bool isNegotiable;

  SavedJob({
    required this.savedId,
    required this.jobId,
    required this.title,
    required this.company,
    required this.location,
    this.companyLogo = '',
    this.salaryFrom,
    this.salaryTo,
    this.isNegotiable = false,
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
    String title = _asString(json['title'] ?? json['name'] ?? json['jobName']);
    String company = _asString(json['company'] ?? json['company_name'] ?? json['companyName']);
    String location = _asString(json['location']);
    String companyLogo = _asString(
      json['companyLogoURL'] ?? json['company_logo_url'] ?? json['companyLogoUrl'] ?? json['logo'] ?? json['companyLogo'],
    );
    int? _asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }
    bool _asBool(dynamic v) {
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      if (v is num) return v != 0;
      return false;
    }
    int? salaryFrom = _asInt(json['salary_from'] ?? json['salaryFrom']);
    int? salaryTo = _asInt(json['salary_to'] ?? json['salaryTo']);
    bool isNegotiable = _asBool(json['is_negotiable'] ?? json['isNegotiable'] ?? json['negotiable']);
    final job = json['job'];
    if (job is Map<String, dynamic>) {
      jobId = jobId.isNotEmpty ? jobId : _asString(job['id']);
      title = title.isNotEmpty ? title : _asString(job['title'] ?? job['name'] ?? job['jobName']);
      company = company.isNotEmpty ? company : _asString(job['company'] ?? job['company_name'] ?? job['companyName']);
      location = location.isNotEmpty ? location : _asString(job['location']);
      // Prefer nested job aliases if present
      salaryFrom = salaryFrom ?? _asInt(job['salary_from'] ?? job['salaryFrom']);
      salaryTo = salaryTo ?? _asInt(job['salary_to'] ?? job['salaryTo']);
      isNegotiable = isNegotiable || _asBool(job['is_negotiable'] ?? job['isNegotiable'] ?? job['negotiable']);
      // Logo aliases nested
      companyLogo = companyLogo.isNotEmpty
          ? companyLogo
          : _asString(job['companyLogoURL'] ?? job['company_logo_url'] ?? job['companyLogoUrl'] ?? job['logo'] ?? job['companyLogo']);
      final companyObj = job['company'];
      if (companyObj is Map<String, dynamic>) {
        company = company.isNotEmpty ? company : _asString(companyObj['name'] ?? companyObj['title'] ?? companyObj['label']);
        companyLogo = companyLogo.isNotEmpty
            ? companyLogo
            : _asString(companyObj['logo'] ?? companyObj['logoUrl'] ?? companyObj['avatar'] ?? companyObj['image'] ?? companyObj['url']);
      }
    }
    return SavedJob(
      savedId: savedId,
      jobId: jobId,
      title: title,
      company: company,
      location: location,
      companyLogo: companyLogo,
      salaryFrom: salaryFrom,
      salaryTo: salaryTo,
      isNegotiable: isNegotiable,
    );
  }
}