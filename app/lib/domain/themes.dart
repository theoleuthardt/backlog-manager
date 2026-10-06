import 'dart:math';

/// The six colours a theme is made of.
class ThemeColors {
  const ThemeColors({
    required this.background,
    required this.surface,
    required this.foreground,
    required this.accent,
    required this.border,
    required this.glow,
  });

  final String background;
  final String surface;
  final String foreground;
  final String accent;
  final String border;
  final String glow;
}

/// A theme the user created; stored with the account.
class CustomTheme {
  const CustomTheme({
    required this.id,
    required this.name,
    required this.colors,
  });

  final String id;
  final String name;
  final ThemeColors colors;
}

class BuiltinTheme {
  const BuiltinTheme({
    required this.id,
    required this.name,
    required this.colors,
  });

  final String id;
  final String name;
  final ThemeColors colors;
}

class ResolvedTheme {
  const ResolvedTheme({
    required this.id,
    required this.name,
    required this.colors,
    required this.builtin,
  });

  final String id;
  final String name;
  final ThemeColors colors;
  final bool builtin;
}

const builtinThemes = [
  BuiltinTheme(
    id: 'shelfOled',
    name: 'Shelf OLED',
    colors: ThemeColors(
      background: '#000000',
      surface: '#0b0b0e',
      foreground: '#f2f2f3',
      accent: '#f5a524',
      border: '#353a4c',
      glow: '#3b82f6',
    ),
  ),
  BuiltinTheme(
    id: 'dark',
    name: 'Dark',
    colors: ThemeColors(
      background: '#000000',
      surface: '#0f0f12',
      foreground: '#ffffff',
      accent: '#2563eb',
      border: '#ffffff',
      glow: '#3b82f6',
    ),
  ),
  BuiltinTheme(
    id: 'light',
    name: 'Light',
    colors: ThemeColors(
      background: '#f5f4ef',
      surface: '#ffffff',
      foreground: '#15151b',
      accent: '#4f46e5',
      border: '#15151b',
      glow: '#818cf8',
    ),
  ),
  BuiltinTheme(
    id: 'colorful',
    name: 'Colorful',
    colors: ThemeColors(
      background: '#0b0720',
      surface: '#1a1240',
      foreground: '#fdf2ff',
      accent: '#ff3ea5',
      border: '#7c4dff',
      glow: '#22d3ee',
    ),
  ),
  BuiltinTheme(
    id: 'freaky',
    name: 'Freaky',
    colors: ThemeColors(
      background: '#04040e',
      surface: '#0e0e26',
      foreground: '#eaffe9',
      accent: '#a3ff12',
      border: '#00ffd0',
      glow: '#ff00e5',
    ),
  ),
];

const defaultThemeId = 'shelfOled';

final _hexColor = RegExp(r'^#[0-9a-fA-F]{6}$');

bool isHexColor(String value) => _hexColor.hasMatch(value);

/// The theme with [themeId]: a built-in, one of [customThemes], or the default
/// when the id is unknown (e.g. a deleted custom theme).
ResolvedTheme resolveTheme(String themeId, List<CustomTheme> customThemes) {
  for (final theme in builtinThemes) {
    if (theme.id == themeId) {
      return ResolvedTheme(
        id: theme.id,
        name: theme.name,
        colors: theme.colors,
        builtin: true,
      );
    }
  }
  for (final theme in customThemes) {
    if (theme.id == themeId) {
      return ResolvedTheme(
        id: theme.id,
        name: theme.name,
        colors: theme.colors,
        builtin: false,
      );
    }
  }
  return resolveTheme(defaultThemeId, const []);
}

/// A fresh `custom-xxxxxxxx` id that is not in [takenIds].
String newCustomThemeId(List<String> takenIds, {Random? random}) {
  final source = random ?? Random.secure();
  String id;
  do {
    final suffix = List.generate(
      8,
      (_) => source.nextInt(16).toRadixString(16),
    ).join();
    id = 'custom-$suffix';
  } while (takenIds.contains(id));
  return id;
}
