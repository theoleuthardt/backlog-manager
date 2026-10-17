import 'package:flutter/services.dart';

/// Loads the font of the app (`PlusJakartaSans`) for a test file. The default
/// test font has square, very wide glyphs and reports overflows the app does
/// not have; a test that measures widths loads the real font first.
Future<void> loadAppFont() async {
  final loader = FontLoader('PlusJakartaSans');
  for (final file in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$file.ttf'));
  }
  await loader.load();
}
