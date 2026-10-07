import 'dart:ui';

import 'package:backlog_manager/domain/themes.dart';

/// The colour of a `#rrggbb` string; anything else is a neutral grey, so a
/// malformed colour of a custom theme never throws while the theme is built.
Color colorFromHex(String hex) {
  if (!isHexColor(hex)) return const Color(0xFF808080);
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

/// A colour as lower-case `#rrggbb`; the opacity is dropped.
String hexOf(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}

/// [a] mixed with the share [t] (0 to 1) of [b], channel by channel in sRGB.
Color mix(Color a, Color b, double t) {
  int channel(int shift) {
    final from = (a.toARGB32() >> shift) & 0xFF;
    final to = (b.toARGB32() >> shift) & 0xFF;
    return (from + (to - from) * t).round();
  }

  return Color.fromARGB(255, channel(16), channel(8), channel(0));
}

/// [color] with the opacity [opacity] (0 to 1).
Color atOpacity(Color color, double opacity) {
  return color.withValues(alpha: opacity);
}

/// WCAG contrast ratio of two colours, from 1 to 21.
double contrastRatio(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}
