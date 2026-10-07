import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

/// Font family bundled in `assets/fonts` (Plus Jakarta Sans, SIL OFL).
const shelfFontFamily = 'PlusJakartaSans';

TextStyle _style(
  Color color,
  double size,
  double lineHeight,
  int weight, [
  double tracking = 0,
]) {
  return TextStyle(
    fontFamily: shelfFontFamily,
    fontSize: size,
    height: lineHeight,
    fontWeight: FontWeight.values[weight ~/ 100 - 1],
    letterSpacing: size * tracking,
    color: color,
  );
}

/// The type scale of the design. Most styles are also the roles of the Material
/// `TextTheme`; the uppercase ones (`eyebrow`, `sidebarLabel`) are written in
/// upper case by the widget, a `TextStyle` cannot do that.
@immutable
class ShelfTextStyles extends ThemeExtension<ShelfTextStyles> {
  const ShelfTextStyles({
    required this.hero,
    required this.page,
    required this.section,
    required this.groupTitle,
    required this.body,
    required this.control,
    required this.label,
    required this.caption,
    required this.eyebrow,
    required this.sidebarLabel,
    required this.coverTitle,
    required this.brand,
    required this.navItem,
    required this.windowTitle,
    required this.fieldText,
    required this.keyHint,
  });

  factory ShelfTextStyles.fromTokens(ShelfTokens tokens) {
    return ShelfTextStyles(
      hero: _style(tokens.foreground, 30, 1.1, 800, -0.02),
      page: _style(tokens.foreground, 26, 1.1, 800, -0.02),
      section: _style(tokens.foreground, 16, 1.25, 800, -0.01),
      groupTitle: _style(tokens.foreground, 13, 1.3, 800),
      body: _style(tokens.foreground, 14, 1.4, 400),
      control: _style(tokens.foreground, 13, 1.2, 600),
      label: _style(tokens.foreground, 12, 1.3, 600),
      caption: _style(tokens.muted, 12.5, 1.3, 400),
      eyebrow: _style(tokens.accent, 11, 1.2, 700, 0.12),
      sidebarLabel: _style(tokens.faint, 11, 1.2, 700, 0.08),
      coverTitle: _style(tokens.foreground, 15, 1.1, 800),
      brand: _style(tokens.foreground, 15, 1.2, 800, -0.01),
      navItem: _style(tokens.foreground, 13.5, 1.2, 600),
      windowTitle: _style(tokens.foreground, 14, 1.2, 700),
      fieldText: _style(tokens.foreground, 13, 1.3, 400),
      keyHint: _style(tokens.faint, 11, 1.2, 600),
    );
  }

  final TextStyle hero;
  final TextStyle page;
  final TextStyle section;
  final TextStyle groupTitle;
  final TextStyle body;
  final TextStyle control;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle eyebrow;
  final TextStyle sidebarLabel;
  final TextStyle coverTitle;
  final TextStyle brand;
  final TextStyle navItem;
  final TextStyle windowTitle;
  final TextStyle fieldText;
  final TextStyle keyHint;

  @override
  ShelfTextStyles copyWith({
    TextStyle? hero,
    TextStyle? page,
    TextStyle? section,
    TextStyle? groupTitle,
    TextStyle? body,
    TextStyle? control,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? eyebrow,
    TextStyle? sidebarLabel,
    TextStyle? coverTitle,
    TextStyle? brand,
    TextStyle? navItem,
    TextStyle? windowTitle,
    TextStyle? fieldText,
    TextStyle? keyHint,
  }) {
    return ShelfTextStyles(
      hero: hero ?? this.hero,
      page: page ?? this.page,
      section: section ?? this.section,
      groupTitle: groupTitle ?? this.groupTitle,
      body: body ?? this.body,
      control: control ?? this.control,
      label: label ?? this.label,
      caption: caption ?? this.caption,
      eyebrow: eyebrow ?? this.eyebrow,
      sidebarLabel: sidebarLabel ?? this.sidebarLabel,
      coverTitle: coverTitle ?? this.coverTitle,
      brand: brand ?? this.brand,
      navItem: navItem ?? this.navItem,
      windowTitle: windowTitle ?? this.windowTitle,
      fieldText: fieldText ?? this.fieldText,
      keyHint: keyHint ?? this.keyHint,
    );
  }

  @override
  ShelfTextStyles lerp(ShelfTextStyles? other, double t) {
    if (other == null) return this;
    TextStyle blend(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return ShelfTextStyles(
      hero: blend(hero, other.hero),
      page: blend(page, other.page),
      section: blend(section, other.section),
      groupTitle: blend(groupTitle, other.groupTitle),
      body: blend(body, other.body),
      control: blend(control, other.control),
      label: blend(label, other.label),
      caption: blend(caption, other.caption),
      eyebrow: blend(eyebrow, other.eyebrow),
      sidebarLabel: blend(sidebarLabel, other.sidebarLabel),
      coverTitle: blend(coverTitle, other.coverTitle),
      brand: blend(brand, other.brand),
      navItem: blend(navItem, other.navItem),
      windowTitle: blend(windowTitle, other.windowTitle),
      fieldText: blend(fieldText, other.fieldText),
      keyHint: blend(keyHint, other.keyHint),
    );
  }
}
