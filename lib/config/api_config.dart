import 'package:flutter/foundation.dart';

class ApiConfig {
  // Điều chỉnh theo backend của bạn nếu khác cổng/đường dẫn
  static const String _androidBaseUrl = 'http://10.0.2.2:8080';
  static const String _iosBaseUrl = 'http://localhost:8080';
  static const String _webBaseUrl = 'http://localhost:8080';

  static String get baseUrl {
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