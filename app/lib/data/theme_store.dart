import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the selected theme and the custom themes on the device, so the theme
/// applies before the network answers and on the sign-in screen. The cache is
/// a convenience: a store that cannot be read or written is ignored.
abstract interface class ThemeStore {
  Future<ThemeSelection?> read();

  Future<void> write(String id, List<CustomTheme> customThemes);
}

const _storageKey = 'blm-theme';

class PreferencesThemeStore implements ThemeStore {
  const PreferencesThemeStore();

  @override
  Future<ThemeSelection?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return decodeThemeCache(prefs.getString(_storageKey));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String id, List<CustomTheme> customThemes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, encodeThemeCache(id, customThemes));
    } on Object {
      return;
    }
  }
}

final themeStoreProvider = Provider<ThemeStore>(
  (ref) => const PreferencesThemeStore(),
);
