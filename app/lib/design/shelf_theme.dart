import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

/// The Material theme of the app, built from the tokens of one theme. The
/// tokens and the text styles are attached as extensions, so widgets read
/// every colour from [ShelfTokens] and never hard-code one.
ThemeData buildShelfTheme(ShelfTokens tokens) {
  final text = ShelfTextStyles.fromTokens(tokens);
  final brightness = tokens.background.computeLuminance() < 0.5
      ? Brightness.dark
      : Brightness.light;
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(ShelfRadius.control),
  );
  OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(ShelfRadius.control),
    borderSide: BorderSide(color: color),
  );

  final scheme = ColorScheme(
    brightness: brightness,
    primary: tokens.accent,
    onPrimary: tokens.onAccent,
    secondary: tokens.glow,
    onSecondary: onColorFor(tokens.glow),
    error: tokens.danger,
    onError: onColorFor(tokens.danger),
    surface: tokens.surface,
    onSurface: tokens.foreground,
    onSurfaceVariant: tokens.muted,
    surfaceContainerLow: tokens.surface,
    surfaceContainer: tokens.surface2,
    surfaceContainerHigh: tokens.surface3,
    outline: tokens.borderStrong,
    outlineVariant: tokens.borderSubtle,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.background,
    canvasColor: tokens.background,
    dividerColor: tokens.borderSubtle,
    fontFamily: shelfFontFamily,
    visualDensity: VisualDensity.compact,
    extensions: [tokens, text],
    textTheme: TextTheme(
      displayMedium: text.hero,
      headlineMedium: text.page,
      titleMedium: text.section,
      titleSmall: text.groupTitle,
      bodyLarge: text.body,
      bodyMedium: text.body,
      bodySmall: text.caption,
      labelLarge: text.control,
      labelMedium: text.label,
      labelSmall: text.eyebrow,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(tokens.accent),
        foregroundColor: WidgetStatePropertyAll(tokens.onAccent),
        minimumSize: const WidgetStatePropertyAll(Size(0, ShelfHeight.control)),
        shape: WidgetStatePropertyAll(controlShape),
        textStyle: WidgetStatePropertyAll(text.control),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(tokens.foreground),
        minimumSize: const WidgetStatePropertyAll(Size(0, ShelfHeight.control)),
        side: WidgetStatePropertyAll(BorderSide(color: tokens.borderStrong)),
        overlayColor: WidgetStatePropertyAll(tokens.glowSoft),
        shape: WidgetStatePropertyAll(controlShape),
        textStyle: WidgetStatePropertyAll(text.control),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      constraints: const BoxConstraints(minHeight: ShelfHeight.input),
      hintStyle: text.body.copyWith(color: tokens.faint),
      enabledBorder: inputBorder(tokens.borderSubtle),
      border: inputBorder(tokens.borderSubtle),
      focusedBorder: inputBorder(tokens.glow),
      errorBorder: inputBorder(tokens.danger),
      focusedErrorBorder: inputBorder(tokens.danger),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShelfRadius.dialog),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(tokens.foreground),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? tokens.accent
            : tokens.surface3,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: tokens.accent,
      labelColor: tokens.foreground,
      unselectedLabelColor: tokens.muted,
      labelStyle: text.control,
      unselectedLabelStyle: text.control,
      dividerColor: tokens.borderSubtle,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(tokens.surface2),
        shape: WidgetStatePropertyAll(controlShape),
        side: WidgetStatePropertyAll(BorderSide(color: tokens.borderStrong)),
      ),
    ),
  );
}
