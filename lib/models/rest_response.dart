typedef ItemParser<T> = T Function(Map<String, dynamic> json);

List<Map<String, dynamic>> _asMapList(List input) {
  return input.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
}

/// Unwrap a paged list from a RestResponse.
/// Expected shape:
/// {
///   "data": { "meta": {...}, "result": [ ... ] }
/// }
/// Fallback keys supported: content, items, list, jobs.
List<Map<String, dynamic>> unwrapPageList(dynamic root) {
  if (root is Map<String, dynamic>) {
    final dataBranch = root['data'];
    if (dataBranch is Map<String, dynamic>) {
      final result = dataBranch['result'];
      if (result is List) return _asMapList(result);
      final alt = dataBranch['content'] ?? dataBranch['items'] ?? dataBranch['list'] ?? dataBranch['jobs'];
      if (alt is List) return _asMapList(alt);
    } else if (dataBranch is List) {
      return _asMapList(dataBranch);
    } else {
      final alt = root['result'] ?? root['content'] ?? root['items'] ?? root['list'] ?? root['jobs'];
      if (alt is List) return _asMapList(alt);
    }
  } else if (root is List) {
    return _asMapList(root);
  }
  return const [];
}

/// Unwrap a direct list from a RestResponse.
/// Expected shape:
/// {
///   "data": [ ... ]
/// }
List<Map<String, dynamic>> unwrapList(dynamic root) {
  if (root is Map<String, dynamic>) {
    final dataBranch = root['data'];
    if (dataBranch is List) return _asMapList(dataBranch);
    // fallback in case backend uses different key at root
    final alt = root['result'] ?? root['content'] ?? root['items'] ?? root['list'] ?? root['jobs'];
    if (alt is List) return _asMapList(alt);
  } else if (root is List) {
    return _asMapList(root);
  }
  return const [];
}

/// Parse a paged list and map into typed objects.
List<T> parsePageList<T>(dynamic root, ItemParser<T> fromJson) {
  final list = unwrapPageList(root);
  return list.map(fromJson).toList();
}

/// Parse a direct list and map into typed objects.
List<T> parseList<T>(dynamic root, ItemParser<T> fromJson) {
  final list = unwrapList(root);
  return list.map(fromJson).toList();
}

/// Extract meta object if available (from data.meta or root.meta)
Map<String, dynamic>? extractMeta(dynamic root) {
  try {
    if (root is Map<String, dynamic>) {
      final dataBranch = root['data'];
      if (dataBranch is Map<String, dynamic>) {
        final meta = dataBranch['meta'];
        if (meta is Map) return meta.cast<String, dynamic>();
      }
      final meta = root['meta'];
      if (meta is Map) return meta.cast<String, dynamic>();
    }
  } catch (_) {}
  return null;
}

/// Extract error message string in a tolerant way.
String extractMessage(dynamic body) {
  try {
    if (body is Map<String, dynamic>) {
      final m = body['message'] ?? body['error'];
      return m?.toString() ?? '';
    }
    return body?.toString() ?? '';
  } catch (_) {
    return '';
  }
}