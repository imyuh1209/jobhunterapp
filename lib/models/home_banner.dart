class HomeBanner {
  final String title;
  final String imageUrl;
  final String link;
  final int? position;
  final bool? active;

  const HomeBanner({
    required this.title,
    required this.imageUrl,
    required this.link,
    this.position,
    this.active,
  });

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    String asString(dynamic v) => v?.toString() ?? '';
    int? asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }
    bool? asBool(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      if (v is num) return v != 0;
      return null;
    }

    // Backend DTO: ResBannerDTO có field imageUrl ("/storage/banner/<fileName>")
    final img = asString(json['imageUrl'] ?? json['image_url'] ?? json['image']);
    return HomeBanner(
      title: asString(json['title'] ?? json['name'] ?? ''),
      imageUrl: img,
      link: asString(json['link'] ?? json['url'] ?? ''),
      position: asInt(json['position']),
      active: asBool(json['active']),
    );
  }
}