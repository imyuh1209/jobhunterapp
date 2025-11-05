import '../config/api_config.dart';

String _basename(String input) {
  final norm = input.replaceAll('\\', '/');
  final idx = norm.lastIndexOf('/');
  return idx >= 0 ? norm.substring(idx + 1) : norm;
}

String _encodeLastSegment(String url) {
  try {
    final u = url;
    final idx = u.lastIndexOf('/');
    if (idx < 0) return Uri.encodeComponent(u);
    final base = u.substring(0, idx + 1);
    final name = u.substring(idx + 1);
    return base + Uri.encodeComponent(name);
  } catch (_) {
    return Uri.encodeFull(url);
  }
}

/// Normalize an image URL to a fully-qualified, encoded URL.
/// - Keeps data URLs unchanged.
/// - If already http/https, encodes the final path segment.
/// - If begins with '/', prefixes with ApiConfig.baseUrl and encodes filename.
/// - Otherwise, treats it as a filename under [defaultPathPrefix].
String buildImageUrl(String? raw, {String defaultPathPrefix = '/storage/company/'}) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return '';
  if (s.startsWith('data:')) return s;
  if (s.startsWith('http://') || s.startsWith('https://')) {
    return _encodeLastSegment(s);
  }
  if (s.startsWith('/')) {
    final encoded = _encodeLastSegment(s);
    return ApiConfig.baseUrl + encoded;
  }
  final name = _basename(s);
  final encodedName = Uri.encodeComponent(name);
  return ApiConfig.baseUrl + defaultPathPrefix + encodedName;
}