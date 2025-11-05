class FormatUtils {
  static String _fmtThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write(',');
        count = 0;
      }
    }
    return buf.toString().split('').reversed.join('');
  }

  // Map mã địa điểm -> tên hiển thị tiếng Việt có dấu
  static const Map<String, String> _locationMap = {
    'HANOI': 'Hà Nội',
    'DANANG': 'Đà Nẵng',
    'HOCHIMINH': 'Hồ Chí Minh',
    'HA_NOI': 'Hà Nội',
    'DA_NANG': 'Đà Nẵng',
    'HO_CHI_MINH': 'Hồ Chí Minh',
  };

  // Chuẩn hóa hiển thị địa điểm: map mã phổ biến, nếu không có thì Title Case nhẹ
  static String formatLocation(String raw) {
    final s = (raw).trim();
    if (s.isEmpty) return '—';
    final key = s.replaceAll(' ', '').toUpperCase();
    final mapped = _locationMap[key];
    if (mapped != null) return mapped;
    // Title case cơ bản cho chuỗi bất kỳ
    return s
        .split(RegExp(r"\s+"))
        .map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1).toLowerCase()))
        .join(' ');
  }

  // Hiển thị lương dạng "x — y đ" hoặc "x đ+" nếu chỉ có min
  // Cố gắng trích xuất số từ chuỗi lương tự do
  static String formatSalaryRange(String raw) {
    final s = (raw).trim();
    if (s.isEmpty) return '—';
    // Lấy các nhóm số liên tiếp, ví dụ: "3,000,000 - 7,000,000 đ" -> [3000000, 7000000]
    final matches = RegExp(r"[0-9][0-9.,]*").allMatches(s).toList();
    if (matches.isEmpty) return s; // giữ nguyên nếu không trích được số
    int parseNum(String t) {
      final cleaned = t.replaceAll(RegExp(r"[.,]"), '');
      return int.tryParse(cleaned) ?? 0;
    }
    final nums = matches.map((m) => parseNum(m.group(0)!)).where((n) => n > 0).toList();
    if (nums.isEmpty) return s;
    if (nums.length == 1) {
      return '${_fmtThousands(nums.first)} đ+';
    }
    final min = nums.reduce((a, b) => a < b ? a : b);
    final max = nums.reduce((a, b) => a > b ? a : b);
    return '${_fmtThousands(min)} — ${_fmtThousands(max)} đ';
  }

  // NEW: Format salary from alias fields with explicit logic
  static String formatSalaryFromTo(int? from, int? to, {bool isNegotiable = false}) {
    // Coerce giá trị không hợp lệ (null/<=0) thành thiếu
    final int? f = (from == null || (from is int && from <= 0)) ? null : from;
    final int? t = (to == null || (to is int && to <= 0)) ? null : to;

    // Hiển thị "Thỏa thuận" nếu đánh dấu hoặc thiếu bất kỳ giá trị nào của khoảng
    if (isNegotiable || f == null || t == null) return 'Thỏa thuận';

    // Nếu hai giá trị bằng nhau cũng coi là không có khoảng rõ ràng
    if (f == t) return 'Thỏa thuận';

    final min = f < t ? f : t;
    final max = f < t ? t : f;
    return '${_fmtThousands(min)} — ${_fmtThousands(max)} đ';
  }
}