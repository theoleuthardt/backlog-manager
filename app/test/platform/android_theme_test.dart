import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Android themes the app starts with, in the light and the dark variant.
const _styles = [
  'android/app/src/main/res/values/styles.xml',
  'android/app/src/main/res/values-night/styles.xml',
];

void main() {
  for (final path in _styles) {
    test('$path turns off the grey focus highlight of Android', () {
      final xml = File(path).readAsStringSync();
      for (final theme in ['LaunchTheme', 'NormalTheme']) {
        final style = RegExp(
          '<style name="$theme"[^>]*>(.*?)</style>',
          dotAll: true,
        ).firstMatch(xml);
        expect(style, isNotNull, reason: theme);
        expect(
          style!.group(1),
          contains(
            '<item name="android:defaultFocusHighlightEnabled">false</item>',
          ),
          reason:
              'Android draws a grey veil over the whole app view when a '
              'controller moves the focus ($theme)',
        );
      }
    });
  }
}
