import 'package:backlog_manager/design/builtin_tokens.dart';
import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter/material.dart';

const _gold = Color(0xFFFFD05A);
const _loudContrast = 7.0;
const _neonChroma = 0.6;

/// Every colour of the Shelf design, derived from the six colours of a theme
/// (or taken from the tuned set of a built-in theme). Widgets read them with
/// `Theme.of(context).extension<ShelfTokens>()!`, never as hard-coded colours.
@immutable
class ShelfTokens extends ThemeExtension<ShelfTokens> {
  const ShelfTokens({
    required this.background,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.foreground,
    required this.text2,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentSoft,
    required this.accentA,
    required this.accentB,
    required this.accentGlow,
    required this.onAccent,
    required this.borderSubtle,
    required this.borderStrong,
    required this.glow,
    required this.glowSoft,
    required this.success,
    required this.danger,
    required this.info,
    required this.shadow,
    required this.scrim,
    required this.sky,
    required this.starA,
    required this.starB,
    required this.starC,
    required this.starHot,
    required this.starHalo,
    required this.starGold,
    required this.starGoldHalo,
    required this.nebula1,
    required this.nebula2,
    required this.nebula3,
    required this.nebula4,
    required this.orbit,
  });

  /// Derives the whole palette of a custom theme from its six colours, with
  /// the formulas of `docs/DESIGN_SYSTEM.md`.
  factory ShelfTokens.fromColors(ThemeColors colors) {
    final background = colorFromHex(colors.background);
    final surface = colorFromHex(colors.surface);
    final foreground = colorFromHex(colors.foreground);
    final accent = colorFromHex(colors.accent);
    final border = colorFromHex(colors.border);
    final glow = colorFromHex(colors.glow);
    final light = background.computeLuminance() >= 0.5;
    final warmAccent = mix(accent, _gold, 0.4);
    return ShelfTokens(
      background: background,
      surface: surface,
      surface2: mix(surface, foreground, 0.03),
      surface3: mix(surface, foreground, 0.06),
      foreground: foreground,
      text2: mix(foreground, background, 0.11),
      muted: mix(foreground, background, 0.35),
      faint: mix(foreground, background, 0.50),
      accent: accent,
      accentSoft: atOpacity(accent, 0.14),
      accentA: mix(accent, const Color(0xFFFFFFFF), 0.2),
      accentB: mix(accent, const Color(0xFF000000), 0.12),
      accentGlow: atOpacity(accent, 0.4),
      onAccent: onColorFor(accent),
      borderSubtle: mix(surface, foreground, 0.08),
      borderStrong: _calmBorder(border, background),
      glow: glow,
      glowSoft: atOpacity(glow, 0.16),
      success: light ? const Color(0xFF047857) : const Color(0xFF34D399),
      danger: light ? const Color(0xFFE11D48) : const Color(0xFFFF6B81),
      info: light ? const Color(0xFF4F46E5) : const Color(0xFF60A5FA),
      shadow: light
          ? atOpacity(foreground, 0.25)
          : atOpacity(const Color(0xFF000000), 0.85),
      scrim: light
          ? atOpacity(foreground, 0.35)
          : atOpacity(const Color(0xFF000000), 0.6),
      sky: atOpacity(glow, 0.24),
      starA: atOpacity(foreground, 0.8),
      starB: atOpacity(accent, 0.55),
      starC: atOpacity(glow, 0.7),
      starHot: atOpacity(foreground, 0.98),
      starHalo: atOpacity(glow, 0.24),
      starGold: atOpacity(warmAccent, 0.95),
      starGoldHalo: atOpacity(warmAccent, 0.22),
      nebula1: atOpacity(glow, 0.30),
      nebula2: atOpacity(accent, 0.12),
      nebula3: atOpacity(mix(glow, accent, 0.5), 0.16),
      nebula4: atOpacity(glow, 0.16),
      orbit: atOpacity(glow, 0.12),
    );
  }

  /// The tokens of [theme]: the tuned set of a built-in theme that has one,
  /// otherwise derived from its six colours.
  factory ShelfTokens.forTheme(ResolvedTheme theme) {
    return builtinShelfTokens[theme.id] ?? ShelfTokens.fromColors(theme.colors);
  }

  final Color background;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color foreground;
  final Color text2;
  final Color muted;
  final Color faint;
  final Color accent;
  final Color accentSoft;
  final Color accentA;
  final Color accentB;
  final Color accentGlow;
  final Color onAccent;
  final Color borderSubtle;
  final Color borderStrong;
  final Color glow;
  final Color glowSoft;
  final Color success;
  final Color danger;
  final Color info;
  final Color shadow;
  final Color scrim;
  final Color sky;
  final Color starA;
  final Color starB;
  final Color starC;
  final Color starHot;
  final Color starHalo;
  final Color starGold;
  final Color starGoldHalo;
  final Color nebula1;
  final Color nebula2;
  final Color nebula3;
  final Color nebula4;
  final Color orbit;

  List<Color> get _colors => [
    background,
    surface,
    surface2,
    surface3,
    foreground,
    text2,
    muted,
    faint,
    accent,
    accentSoft,
    accentA,
    accentB,
    accentGlow,
    onAccent,
    borderSubtle,
    borderStrong,
    glow,
    glowSoft,
    success,
    danger,
    info,
    sky,
    starA,
    starB,
    starC,
    starHot,
    starHalo,
    starGold,
    starGoldHalo,
    nebula1,
    nebula2,
    nebula3,
    nebula4,
    orbit,
    shadow,
    scrim,
  ];

  @override
  ShelfTokens copyWith({
    Color? background,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? foreground,
    Color? text2,
    Color? muted,
    Color? faint,
    Color? accent,
    Color? accentSoft,
    Color? accentA,
    Color? accentB,
    Color? accentGlow,
    Color? onAccent,
    Color? borderSubtle,
    Color? borderStrong,
    Color? glow,
    Color? glowSoft,
    Color? success,
    Color? danger,
    Color? info,
    Color? shadow,
    Color? scrim,
    Color? sky,
    Color? starA,
    Color? starB,
    Color? starC,
    Color? starHot,
    Color? starHalo,
    Color? starGold,
    Color? starGoldHalo,
    Color? nebula1,
    Color? nebula2,
    Color? nebula3,
    Color? nebula4,
    Color? orbit,
  }) {
    return ShelfTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      foreground: foreground ?? this.foreground,
      text2: text2 ?? this.text2,
      muted: muted ?? this.muted,
      faint: faint ?? this.faint,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentA: accentA ?? this.accentA,
      accentB: accentB ?? this.accentB,
      accentGlow: accentGlow ?? this.accentGlow,
      onAccent: onAccent ?? this.onAccent,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      glow: glow ?? this.glow,
      glowSoft: glowSoft ?? this.glowSoft,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
      sky: sky ?? this.sky,
      starA: starA ?? this.starA,
      starB: starB ?? this.starB,
      starC: starC ?? this.starC,
      starHot: starHot ?? this.starHot,
      starHalo: starHalo ?? this.starHalo,
      starGold: starGold ?? this.starGold,
      starGoldHalo: starGoldHalo ?? this.starGoldHalo,
      nebula1: nebula1 ?? this.nebula1,
      nebula2: nebula2 ?? this.nebula2,
      nebula3: nebula3 ?? this.nebula3,
      nebula4: nebula4 ?? this.nebula4,
      orbit: orbit ?? this.orbit,
    );
  }

  @override
  ShelfTokens lerp(ShelfTokens? other, double t) {
    if (other == null) return this;
    Color blend(Color a, Color b) => Color.lerp(a, b, t)!;
    return ShelfTokens(
      background: blend(background, other.background),
      surface: blend(surface, other.surface),
      surface2: blend(surface2, other.surface2),
      surface3: blend(surface3, other.surface3),
      foreground: blend(foreground, other.foreground),
      text2: blend(text2, other.text2),
      muted: blend(muted, other.muted),
      faint: blend(faint, other.faint),
      accent: blend(accent, other.accent),
      accentSoft: blend(accentSoft, other.accentSoft),
      accentA: blend(accentA, other.accentA),
      accentB: blend(accentB, other.accentB),
      accentGlow: blend(accentGlow, other.accentGlow),
      onAccent: blend(onAccent, other.onAccent),
      borderSubtle: blend(borderSubtle, other.borderSubtle),
      borderStrong: blend(borderStrong, other.borderStrong),
      glow: blend(glow, other.glow),
      glowSoft: blend(glowSoft, other.glowSoft),
      success: blend(success, other.success),
      danger: blend(danger, other.danger),
      info: blend(info, other.info),
      shadow: blend(shadow, other.shadow),
      scrim: blend(scrim, other.scrim),
      sky: blend(sky, other.sky),
      starA: blend(starA, other.starA),
      starB: blend(starB, other.starB),
      starC: blend(starC, other.starC),
      starHot: blend(starHot, other.starHot),
      starHalo: blend(starHalo, other.starHalo),
      starGold: blend(starGold, other.starGold),
      starGoldHalo: blend(starGoldHalo, other.starGoldHalo),
      nebula1: blend(nebula1, other.nebula1),
      nebula2: blend(nebula2, other.nebula2),
      nebula3: blend(nebula3, other.nebula3),
      nebula4: blend(nebula4, other.nebula4),
      orbit: blend(orbit, other.orbit),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ShelfTokens) return false;
    final mine = _colors;
    final theirs = other._colors;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != theirs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_colors);
}

/// A loud border (white, black or neon) is blended into the background so
/// outlines stay calm: 55% for a saturated colour, 20% for a high contrast
/// neutral; a calm border is used as it is.
Color _calmBorder(Color border, Color background) {
  final rgb = [16, 8, 0].map((shift) => (border.toARGB32() >> shift) & 0xFF);
  final chroma =
      (rgb.reduce((a, b) => a > b ? a : b) -
          rgb.reduce((a, b) => a < b ? a : b)) /
      255;
  if (chroma >= _neonChroma) return mix(background, border, 0.55);
  if (contrastRatio(border, background) >= _loudContrast) {
    return mix(background, border, 0.2);
  }
  return border;
}
