class Job {
  final String id;
  final String title;
  final String company;
  final String location;
  final String description;
  // Optional UI fields
  final String companyLogo; // URL hoặc base64, nếu có
  final String salary; // Dạng hiển thị, VD: "5,000,000 đ"

  Job({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.description,
    this.companyLogo = '',
    this.salary = '',
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    String asString(dynamic value, [List<String> nestedKeys = const []]) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is num || value is bool) return value.toString();
      if (value is Map) {
        for (final k in nestedKeys) {
          final v = value[k];
          if (v is String) return v;
          if (v is num || v is bool) return v.toString();
        }
        final vName = value['name'] ?? value['title'] ?? value['label'];
        if (vName != null) return vName.toString();
        return value.toString();
      }
      if (value is List) return value.map((e) => e.toString()).join(', ');
      return value.toString();
    }
    String _extractLogo(dynamic c, dynamic root) {
      // Ưu tiên từ company object
      if (c is Map<String, dynamic>) {
        final l = c['logo'] ?? c['logoUrl'] ?? c['avatar'] ?? c['image'] ?? c['url'];
        if (l is String && l.isNotEmpty) return l;
      }
      // Fallback từ root
      final l2 = root is Map<String, dynamic>
          ? (root['logo'] ?? root['logoUrl'] ?? root['companyLogo'])
          : null;
      if (l2 is String && l2.isNotEmpty) return l2;
      return '';
    }

    String _extractSalary(Map<String, dynamic> m) {
      final s = m['salary'] ?? m['salaryText'] ?? m['budget'];
      if (s is String && s.isNotEmpty) return s;
      final min = m['salaryMin'] ?? m['minSalary'];
      final max = m['salaryMax'] ?? m['maxSalary'];
      String fmt(num? v) {
        if (v == null) return '';
        final str = v.toString();
        return str; // giữ nguyên, backend có thể đã format
      }
      num? toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '');
      final minN = toNum(min);
      final maxN = toNum(max);
      if (minN != null && maxN != null) return '${fmt(minN)} - ${fmt(maxN)} đ';
      if (minN != null) return '${fmt(minN)} đ';
      if (maxN != null) return '${fmt(maxN)} đ';
      return '';
    }

    return Job(
      id: json['id']?.toString() ?? '',
      // backend có thể dùng 'name' thay vì 'title'
      title: asString(json['title'] ?? json['name']),
      // một số API có company là object -> lấy name/title/label
      company: asString(
        json['company'] ?? json['companyName'] ?? json['employer'],
        const ['name', 'title']
      ),
      // fallback cho địa điểm, hỗ trợ object
      location: asString(
        json['location'] ?? json['address'] ?? json['city'] ?? json['province'],
        const ['name', 'title', 'label']
      ),
      description: asString(json['description']),
      companyLogo: _extractLogo(json['company'], json),
      salary: _extractSalary(json is Map<String, dynamic> ? json : {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'company': company,
        'location': location,
        'description': description,
        'companyLogo': companyLogo,
        'salary': salary,
      };
}