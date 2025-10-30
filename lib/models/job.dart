class Job {
  final String id;
  final String title;
  final String company;
  final String location;
  final String description;

  Job({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.description,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'company': company,
        'location': location,
        'description': description,
      };
}