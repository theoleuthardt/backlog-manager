import 'package:backlog_manager/shell/shell_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('on a phone or tablet', () {
    ShellLayout on(double width, double height) =>
        shellLayoutFor(Size(width, height), desktop: false);

    test('a phone in portrait is compact', () {
      expect(on(402, 874), ShellLayout.compact);
      expect(on(360, 780), ShellLayout.compact);
    });

    test('a phone in landscape is medium', () {
      expect(on(874, 402), ShellLayout.medium);
    });

    test('the handhelds in landscape are medium', () {
      expect(on(732, 412), ShellLayout.medium);
      expect(on(960, 540), ShellLayout.medium);
    });

    test('a tablet in portrait is medium', () {
      expect(on(820, 1180), ShellLayout.medium);
    });

    test('a tablet in landscape gets the full window', () {
      expect(on(1180, 820), ShellLayout.expanded);
    });

    test('a wide but low screen is medium', () {
      expect(on(1200, 560), ShellLayout.medium);
      expect(on(1000, 639), ShellLayout.medium);
    });

    test('the thresholds are exact', () {
      expect(on(599, 874), ShellLayout.compact);
      expect(on(600, 874), ShellLayout.medium);
      expect(on(999, 640), ShellLayout.medium);
      expect(on(1000, 640), ShellLayout.expanded);
    });
  });

  test('the desktop always keeps its window, whatever its size', () {
    for (final size in const [
      Size(1440, 900),
      Size(1000, 640),
      Size(800, 600),
    ]) {
      expect(
        shellLayoutFor(size, desktop: true),
        ShellLayout.expanded,
        reason: '$size',
      );
    }
  });
}
