import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final saved = await _storage.read(key: 'themeMode');
      switch (saved) {
        case 'light':
          _mode = ThemeMode.light;
          break;
        case 'dark':
          _mode = ThemeMode.dark;
          break;
        case 'system':
        default:
          _mode = ThemeMode.system;
      }
    } catch (_) {
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    try {
      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await _storage.write(key: 'themeMode', value: value);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> toggle() async {
    final next = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }
}

class ThemeProvider extends InheritedNotifier<ThemeController> {
  const ThemeProvider({super.key, required super.notifier, required super.child});

  static ThemeController of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
    assert(provider != null, 'ThemeProvider not found in context');
    return provider!.notifier!;
  }

  @override
  bool updateShouldNotify(covariant ThemeProvider oldWidget) => true;
}