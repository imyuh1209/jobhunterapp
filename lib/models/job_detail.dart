import '../utils/url_utils.dart';

class JobDetail {
  final String id;
  final String title;
  final String description;
  final String location;
  final String salary;
  // NEW alias fields from backend
  final int? salaryFrom;
  final int? salaryTo;
  final bool isNegotiable;
  final String quantity;
  final String level;
  final String startDate;
  final String endDate;
  final bool active;
  final CompanyInfo company;
  final List<Skill> skills;
  final bool saved;
  final bool applied;
  final int applicantCount;

  JobDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.salary,
    this.salaryFrom,
    this.salaryTo,
    this.isNegotiable = false,
    required this.quantity,
    required this.level,
    required this.startDate,
    required this.endDate,
    required this.active,
    required this.company,
    required this.skills,
    required this.saved,
    required this.applied,
    required this.applicantCount,
  });

  factory JobDetail.fromJson(Map<String, dynamic> json) {
    String asString(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      if (v is num || v is bool) return v.toString();
      return v.toString();
    }
    bool asBool(dynamic v) {
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      if (v is num) return v != 0;
      return false;
    }
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    final compRaw = json['company'];
    final company = compRaw is Map<String, dynamic>
        ? CompanyInfo.fromJson(compRaw)
        : CompanyInfo.empty();

    final skillsRaw = json['skills'];
    final skills = <Skill>[];
    if (skillsRaw is List) {
      for (final e in skillsRaw) {
        if (e is Map<String, dynamic>) skills.add(Skill.fromJson(e));
      }
    }

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

    return JobDetail(
      id: asString(json['id']),
      title: asString(json['name']),
      description: asString(json['description']),
      location: asString(json['location']),
      salary: asString(json['salary']),
      salaryFrom: _asInt(json['salary_from'] ?? json['salaryFrom']),
      salaryTo: _asInt(json['salary_to'] ?? json['salaryTo']),
      isNegotiable: _asBool(json['is_negotiable'] ?? json['isNegotiable'] ?? json['negotiable']),
      quantity: asString(json['quantity']),
      level: asString(json['level']),
      startDate: asString(json['startDate']),
      endDate: asString(json['endDate']),
      active: asBool(json['active']),
      company: company,
      skills: skills,
      saved: asBool(json['saved']),
      applied: asBool(json['applied']),
      applicantCount: asInt(json['applicantCount']),
    );
  }
}

class CompanyInfo {
  final String id;
  final String name;
  final String description;
  final String address;
  final String logo;

  CompanyInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.logo,
  });

  factory CompanyInfo.fromJson(Map<String, dynamic> json) {
    String asString(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      if (v is num || v is bool) return v.toString();
      return v.toString();
    }
    return CompanyInfo(
      id: asString(json['id']),
      name: asString(json['name']),
      description: asString(json['description']),
      address: asString(json['address']),
      logo: buildImageUrl(asString(json['logo'])),
    );
  }

  factory CompanyInfo.empty() => CompanyInfo(id: '', name: '', description: '', address: '', logo: '');
}

class Skill {
  final String id;
  final String name;
  Skill({required this.id, required this.name});
  factory Skill.fromJson(Map<String, dynamic> json) {
    String asString(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      if (v is num || v is bool) return v.toString();
      return v.toString();
    }
    return Skill(id: asString(json['id']), name: asString(json['name']));
  }
}