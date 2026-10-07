import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The id of the active theme. Storing it with the account comes with the
/// appearance screen.
class ThemeIdNotifier extends Notifier<String> {
  @override
  String build() => defaultThemeId;

  void select(String id) => state = id;
}

final themeIdProvider = NotifierProvider<ThemeIdNotifier, String>(
  ThemeIdNotifier.new,
);

/// The Material theme of the active theme.
final shelfThemeProvider = Provider<ThemeData>((ref) {
  final theme = resolveTheme(ref.watch(themeIdProvider), const []);
  return buildShelfTheme(ShelfTokens.forTheme(theme));
});
