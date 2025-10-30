class AuthResponse {
  final String token;

  AuthResponse({required this.token});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> src =
        (json['data'] is Map<String, dynamic>) ? json['data'] as Map<String, dynamic> : json;
    final dynamic t = src['token'] ?? src['access_token'] ?? src['accessToken'];
    return AuthResponse(token: (t is String) ? t : (t?.toString() ?? ''));
  }

  Map<String, dynamic> toJson() => {
        'token': token,
      };
}