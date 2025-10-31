class Resume {
  final String id;
  final String? email;
  final String? url;
  final String? status;
  final int? userId;
  final String? jobId;
  final String? jobTitle;

  Resume({
    required this.id,
    this.email,
    this.url,
    this.status,
    this.userId,
    this.jobId,
    this.jobTitle,
  });

  factory Resume.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'] ?? json['_id'] ?? json['resumeId'];
    final user = json['user'];
    final job = json['job'];
    int? uid;
    String? jid;
    String? jtitle;
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
    }
    return Resume(
      id: idRaw?.toString() ?? '',
      email: json['email']?.toString(),
      url: json['url']?.toString(),
      status: json['status']?.toString(),
      userId: uid,
      jobId: jid,
      jobTitle: jtitle,
    );
  }
}