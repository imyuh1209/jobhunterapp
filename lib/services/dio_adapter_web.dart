import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

// Web: bật withCredentials để gửi/nhận cookie (refresh_token)
HttpClientAdapter buildAdapterWithCredentials() {
  return BrowserHttpClientAdapter(withCredentials: true);
}