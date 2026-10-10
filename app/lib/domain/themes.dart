import 'dart:convert';
import 'dart:math';

/// The six colours of a theme, in the order of the theme form.
enum ThemeColorField {
  background('Background', 'Page background'),
  surface('Surface', 'Cards, dialogs and menus'),
  foreground('Text', 'Text and icons'),
  accent('Accent', 'Buttons and highlights'),
  border('Border', 'Outlines and dividers'),
  glow('Glow', 'Glow and gradient tint');

  const ThemeColorField(this.label, this.hint);

  final String label;
  final String hint;
}

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

  String colorOf(ThemeColorField field) => switch (field) {
    ThemeColorField.background => background,
    ThemeColorField.surface => surface,
    ThemeColorField.foreground => foreground,
    ThemeColorField.accent => accent,
    ThemeColorField.border => border,
    ThemeColorField.glow => glow,
  };

  /// These colours with [field] set to [value].
  ThemeColors withColor(ThemeColorField field, String value) {
    String pick(ThemeColorField candidate) =>
        candidate == field ? value : colorOf(candidate);
    return ThemeColors(
      background: pick(ThemeColorField.background),
      surface: pick(ThemeColorField.surface),
      foreground: pick(ThemeColorField.foreground),
      accent: pick(ThemeColorField.accent),
      border: pick(ThemeColorField.border),
      glow: pick(ThemeColorField.glow),
    );
  }

  /// Whether all six are `#rrggbb` colours.
  bool get isValid =>
      ThemeColorField.values.every((field) => isHexColor(colorOf(field)));

  @override
  bool operator ==(Object other) =>
      other is ThemeColors &&
      ThemeColorField.values.every(
        (field) => colorOf(field) == other.colorOf(field),
      );

  @override
  int get hashCode => Object.hashAll(ThemeColorField.values.map(colorOf));
}

/// A theme the user created; stored with the account.
class CustomTheme {
  const CustomTheme({
    required this.id,
    required this.name,
    required this.colors,
  });

  factory CustomTheme.fromJson(Map<String, dynamic> json) {
    return CustomTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      colors: ThemeColors(
        background: json['background'] as String,
        surface: json['surface'] as String,
        foreground: json['foreground'] as String,
        accent: json['accent'] as String,
        border: json['border'] as String,
        glow: json['glow'] as String,
      ),
    );
  }

  final String id;
  final String name;
  final ThemeColors colors;

  /// The flat shape the backend stores: the name and the six colours beside
  /// the id.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    for (final field in ThemeColorField.values)
      field.name: colors.colorOf(field),
  };
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
    name: 'Classic dark',
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

/// The built-in themes as the appearance screen lists them: the old dark
/// theme, which keeps its id, comes last.
List<BuiltinTheme> get displayThemes => [
  for (final theme in builtinThemes)
    if (theme.id != 'dark') theme,
  builtinThemes.firstWhere((theme) => theme.id == 'dark'),
];

const maxCustomThemes = 10;
const themeNameMaxLength = 30;

/// Whether the theme form can be saved: a name, six valid colours and, for a
/// new theme, room below the limit of [maxCustomThemes].
bool canSaveTheme({
  required String name,
  required ThemeColors colors,
  required int customCount,
  required bool editing,
}) {
  final atLimit = !editing && customCount >= maxCustomThemes;
  return name.trim().isNotEmpty && colors.isValid && !atLimit;
}

const themeLimitMessage =
    'You can keep up to $maxCustomThemes custom themes - delete one to save '
    'another.';

String themeSavedMessage(String name) => 'Theme "$name" saved';

String themeDeletedMessage(String name) => 'Theme "$name" deleted';

/// The selected theme and the custom themes, as the app keeps them on the
/// device so the theme applies before the network answers.
class ThemeSelection {
  const ThemeSelection({required this.id, required this.customThemes});

  final String id;
  final List<CustomTheme> customThemes;
}

String encodeThemeCache(String id, List<CustomTheme> customThemes) {
  return jsonEncode({
    'id': id,
    'customThemes': [for (final theme in customThemes) theme.toJson()],
  });
}

/// The selection stored by [encodeThemeCache] (or by the web client, which
/// stores more beside it), or null when [text] holds none. Themes that are
/// not complete are dropped.
ThemeSelection? decodeThemeCache(String? text) {
  if (text == null) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  final id = decoded['id'];
  if (id is! String) return null;
  final stored = decoded['customThemes'];
  final themes = <CustomTheme>[];
  if (stored is List<dynamic>) {
    for (final item in stored) {
      if (item is! Map<String, dynamic>) continue;
      try {
        themes.add(CustomTheme.fromJson(item));
      } on TypeError {
        continue;
      }
    }
  }
  return ThemeSelection(id: id, customThemes: themes);
}
