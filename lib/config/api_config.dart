import 'package:flutter/foundation.dart';

class ApiConfig {
  // Điều chỉnh theo backend của bạn nếu khác cổng/đường dẫn
  static const String _androidBaseUrl = 'http://10.0.2.2:8080';
  static const String _iosBaseUrl = 'http://localhost:8080';
  static const String _webBaseUrl = 'http://localhost:8080';
  // Allow override via --dart-define=BACKEND_URL=http://host:port
  static const String _envBaseUrl = String.fromEnvironment('BACKEND_URL');

  static String get baseUrl {
    // Ưu tiên biến môi trường nếu cấu hình
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return _webBaseUrl;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidBaseUrl;
      case TargetPlatform.iOS:
        return _iosBaseUrl;
      default:
        return _iosBaseUrl;
    }
  }
}