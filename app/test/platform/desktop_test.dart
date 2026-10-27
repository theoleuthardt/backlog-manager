import 'package:backlog_manager/platform/desktop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS, Windows and Linux are desktop systems', () {
    for (final os in ['macos', 'windows', 'linux']) {
      expect(isDesktopPlatform(operatingSystem: os), isTrue, reason: os);
    }
  });

  test('Android and iOS are not', () {
    for (final os in ['android', 'ios']) {
      expect(isDesktopPlatform(operatingSystem: os), isFalse, reason: os);
    }
  });

  test('the tests themselves run on a desktop system', () {
    expect(isDesktopPlatform(), isTrue);
  });
}
