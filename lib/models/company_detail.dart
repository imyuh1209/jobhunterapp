class CompanyDetail {
  final String id;
  final String name;
  final String description;
  final String address;
  final String logo;
  final List<JobSimple> jobs;

  CompanyDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.logo,
    required this.jobs,
  });

  factory CompanyDetail.fromJson(Map<String, dynamic> json) {
    String asString(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      if (v is num || v is bool) return v.toString();
      return v.toString();
    }

    final jobsRaw = json['jobs'];
    final jobs = <JobSimple>[];
    if (jobsRaw is List) {
      for (final e in jobsRaw) {
        if (e is Map<String, dynamic>) jobs.add(JobSimple.fromJson(e));
      }
    }
    return CompanyDetail(
      id: asString(json['id']),
      name: asString(json['name']),
      description: asString(json['description']),
      address: asString(json['address']),
      logo: asString(json['logo']),
      jobs: jobs,
    );
  }
}

class JobSimple {
  final String id;
  final String name;
  JobSimple({required this.id, required this.name});

  factory JobSimple.fromJson(Map<String, dynamic> json) {
    String asString(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      if (v is num || v is bool) return v.toString();
      return v.toString();
    }
    return JobSimple(id: asString(json['id']), name: asString(json['name']));
  }
}