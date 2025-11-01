class SkillRef {
  final String id;
  final String name;
  SkillRef({required this.id, required this.name});
}

class Subscriber {
  final String id;
  final String email;
  final String name;
  final List<SkillRef> skills;

  Subscriber({required this.id, required this.email, required this.name, this.skills = const []});

  factory Subscriber.fromJson(Map<String, dynamic> m) {
    final List<SkillRef> skills = [];
    if (m['skills'] is List) {
      for (final s in m['skills']) {
        if (s is Map) {
          final id = s['id']?.toString() ?? '';
          final name = s['name']?.toString() ?? '';
          skills.add(SkillRef(id: id, name: name));
        } else if (s is String) {
          skills.add(SkillRef(id: '', name: s));
        }
      }
    }
    return Subscriber(
      id: m['id']?.toString() ?? '',
      email: m['email']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      skills: skills,
    );
  }
}