import '../utils/url_utils.dart';

class CompanyBrief {
  final String id;
  final String name;
  final String logo; // full URL

  const CompanyBrief({required this.id, required this.name, required this.logo});

  factory CompanyBrief.fromJson(Map<String, dynamic> json) {
    String asString(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      if (v is num || v is bool) return v.toString();
      return v.toString();
    }

    return CompanyBrief(
      id: asString(json['id'] ?? json['_id'] ?? json['companyId']),
      name: asString(json['name'] ?? json['title'] ?? json['label'] ?? json['companyName']),
      logo: buildImageUrl(
        asString(
          json['logo'] ??
              json['logoUrl'] ??
              json['logoURL'] ??
              json['logo_url'] ??
              json['avatar'] ??
              json['image'] ??
              json['url'],
        ),
      ),
    );
  }
}