import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The id of the active theme. Saving it with the account is done by
/// `ThemeActions`, this only holds what the app shows.
class ThemeIdNotifier extends Notifier<String> {
  @override
  String build() => defaultThemeId;

  void select(String id) => state = id;
}

final themeIdProvider = NotifierProvider<ThemeIdNotifier, String>(
  ThemeIdNotifier.new,
);

/// The themes the user created.
class CustomThemesNotifier extends Notifier<List<CustomTheme>> {
  @override
  List<CustomTheme> build() => const [];

  void set(List<CustomTheme> themes) => state = themes;
}

final customThemesProvider =
    NotifierProvider<CustomThemesNotifier, List<CustomTheme>>(
      CustomThemesNotifier.new,
    );

/// Colours shown instead of the active theme while the theme form is open,
/// null when none are previewed.
class ThemePreviewNotifier extends Notifier<ThemeColors?> {
  @override
  ThemeColors? build() => null;

  void set(ThemeColors? colors) => state = colors;

  /// Drops the preview unless the app is already shutting down.
  void clear() {
    if (ref.mounted) state = null;
  }
}

final themePreviewProvider =
    NotifierProvider<ThemePreviewNotifier, ThemeColors?>(
      ThemePreviewNotifier.new,
    );

/// The theme to show: the active one, or the colours being edited.
final resolvedThemeProvider = Provider<ResolvedTheme>((ref) {
  final preview = ref.watch(themePreviewProvider);
  final theme = resolveTheme(
    ref.watch(themeIdProvider),
    ref.watch(customThemesProvider),
  );
  if (preview == null) return theme;
  return ResolvedTheme(
    id: 'preview',
    name: theme.name,
    colors: preview,
    builtin: false,
  );
});

/// The Material theme of the active theme.
final shelfThemeProvider = Provider<ThemeData>((ref) {
  return buildShelfTheme(
    ShelfTokens.forTheme(ref.watch(resolvedThemeProvider)),
  );
});
