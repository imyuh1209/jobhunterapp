class UserProfile {
  final String id;
  final String email;
  final String? name;
  final String? gender; // backend enum: MALE/FEMALE/OTHER
  final String? address;
  final int? age;
  final String? role;
  final String? company;

  UserProfile({
    required this.id,
    required this.email,
    this.name,
    this.gender,
    this.address,
    this.age,
    this.role,
    this.company,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    String _asString(dynamic v) => v?.toString() ?? '';
    int? _asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }
    final idRaw = json['id'] ?? json['_id'] ?? json['userId'];
    final emailRaw = json['email'] ?? json['username'];
    return UserProfile(
      id: _asString(idRaw),
      email: _asString(emailRaw),
      name: json['name']?.toString(),
      gender: json['gender']?.toString(),
      address: json['address']?.toString(),
      age: _asInt(json['age']),
      role: json['role']?.toString(),
      company: json['company']?.toString(),
    );
  }
}