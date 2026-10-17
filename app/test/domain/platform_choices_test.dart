import 'package:backlog_manager/domain/platform_choices.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('platformChoices', () {
    test('lists the selected platforms first, in their order', () {
      final choices = platformChoices(
        selected: ['Switch', 'PC'],
        inBacklog: ['PC', 'PS5'],
      );

      expect(choices.take(2), ['Switch', 'PC']);
    });

    test('then the platforms of the backlog, then the common ones', () {
      final choices = platformChoices(
        selected: ['PC'],
        inBacklog: ['PC', 'GOG Galaxy', 'PS5'],
      );

      expect(choices.sublist(0, 3), ['PC', 'GOG Galaxy', 'PS5']);
      expect(choices, containsAll(commonPlatforms));
    });

    test('lists every platform once, whatever the case', () {
      final choices = platformChoices(
        selected: ['pc'],
        inBacklog: ['PC', 'Pc'],
      );

      expect(choices.where((c) => c.toLowerCase() == 'pc'), ['pc']);
    });

    test('keeps a selected platform that nobody else knows', () {
      expect(
        platformChoices(selected: ['Amiga'], inBacklog: const []),
        contains('Amiga'),
      );
    });
  });

  group('togglePlatform', () {
    test('adds a platform that is not selected, at the end', () {
      expect(togglePlatform(['PC'], 'PS5'), ['PC', 'PS5']);
    });

    test('removes a selected platform, whatever the case', () {
      expect(togglePlatform(['PC', 'PS5'], 'pc'), ['PS5']);
    });
  });

  group('addPlatform', () {
    test('adds the typed name, trimmed', () {
      expect(addPlatform(['PC'], '  Amiga '), ['PC', 'Amiga']);
    });

    test('ignores an empty name and one that is already selected', () {
      expect(addPlatform(['PC'], '   '), ['PC']);
      expect(addPlatform(['PC'], 'pc'), ['PC']);
    });

    test('does not take a comma: it would split the name in the list', () {
      expect(addPlatform(['PC'], 'Atari, 2600'), ['PC']);
    });
  });
}
