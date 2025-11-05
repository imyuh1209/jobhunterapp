class Resume {
  final String id;
  final String? email;
  final String? url;
  final String? status;
  final int? userId;
  final String? jobId;
  final String? jobTitle;
  final String? companyName;
  final DateTime? createdAt;

  Resume({
    required this.id,
    this.email,
    this.url,
    this.status,
    this.userId,
    this.jobId,
    this.jobTitle,
    this.companyName,
    this.createdAt,
  });

  factory Resume.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'] ?? json['_id'] ?? json['resumeId'];
    final user = json['user'];
    final job = json['job'];
    int? uid;
    String? jid;
    String? jtitle;
    String? compName;
    DateTime? cAt;
    if (user is Map<String, dynamic>) {
      final uidRaw = user['id'] ?? user['_id'];
      if (uidRaw is int) uid = uidRaw;
      if (uidRaw is String) {
        final parsed = int.tryParse(uidRaw);
        uid = parsed ?? uid;
      }
    }
    if (job is Map<String, dynamic>) {
      final jRaw = job['id'] ?? job['_id'];
      if (jRaw is String) jid = jRaw;
      if (jRaw is int) jid = jRaw.toString();
      jtitle = job['title']?.toString();
      compName = job['companyName']?.toString() ?? job['company_name']?.toString();
      final compObj = job['company'];
      if (compObj is Map<String, dynamic>) {
        compName = compName ?? compObj['name']?.toString() ?? compObj['title']?.toString();
      }
    }
    final createdRaw = json['createdAt'] ?? json['created_at'] ?? json['created'];
    if (createdRaw is String) {
      cAt = DateTime.tryParse(createdRaw);
    } else if (createdRaw is int) {
      // epoch millis
      cAt = DateTime.fromMillisecondsSinceEpoch(createdRaw, isUtc: true);
    }
    return Resume(
      id: idRaw?.toString() ?? '',
      email: json['email']?.toString(),
      url: json['url']?.toString(),
      status: json['status']?.toString(),
      userId: uid,
      jobId: jid,
      jobTitle: jtitle,
      companyName: compName,
      createdAt: cAt,
    );
  }
}