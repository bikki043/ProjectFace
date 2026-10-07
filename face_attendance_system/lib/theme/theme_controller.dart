import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'app_colors.dart';

/// Single source of truth for "how the app looks right now".
///
/// Call [ThemeController.instance.init] once before runApp. Every
/// screen that should react live to a theme change wraps its own
/// build() output in an AnimatedBuilder listening to this controller
/// (see home_screen.dart / login_screen.dart / settings_screen.dart)
/// — that forces that screen to fully rebuild and read the fresh
/// AppColors values whenever setMode/setAccent runs.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _modeKey = 'settings.theme_mode';
  static const _accentKey = 'settings.accent';

  ThemeMode _mode = ThemeMode.dark;
  AppAccent _accent = AppAccent.indigo;

  ThemeMode get mode => _mode;
  AppAccent get accent => _accent;

  /// AppColors has no BuildContext, so when mode == system we resolve
  /// the OS brightness once here instead.
  Brightness get _resolvedBrightness {
    if (_mode == ThemeMode.light) return Brightness.light;
    if (_mode == ThemeMode.dark) return Brightness.dark;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  AppPalette get currentPalette => _resolvedBrightness == Brightness.dark
      ? AppPalette.dark(_accent)
      : AppPalette.light(_accent);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_modeKey);
    final savedAccent = prefs.getString(_accentKey);

    _mode = ThemeMode.values.firstWhere(
      (m) => m.name == savedMode,
      orElse: () => ThemeMode.dark,
    );
    _accent = AppAccent.values.firstWhere(
      (a) => a.name == savedAccent,
      orElse: () => AppAccent.indigo,
    );
    AppColors.apply(currentPalette);
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    AppColors.apply(currentPalette);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  Future<void> setAccent(AppAccent accent) async {
    _accent = accent;
    AppColors.apply(currentPalette);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentKey, accent.name);
  }
}
