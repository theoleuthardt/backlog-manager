import 'package:backlog_manager/domain/text_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareText', () {
    List<String> sorted(List<String> values) => [...values]..sort(compareText);

    test('orders letters case-insensitively', () {
      expect(sorted(['story', 'Co-op', 'Backlog night']), [
        'Backlog night',
        'Co-op',
        'story',
      ]);
    });

    test('puts the lower-case spelling first on a tie', () {
      expect(sorted(['Celeste', 'celeste']), ['celeste', 'Celeste']);
    });

    test('sorts accented letters with their base letter', () {
      expect(sorted(['Zelda', 'Über', 'Ärger', 'Apfel', 'Umbra', 'éco']), [
        'Apfel',
        'Ärger',
        'éco',
        'Über',
        'Umbra',
        'Zelda',
      ]);
    });

    test('puts an unaccented spelling before the accented one', () {
      expect(sorted(['Café', 'Cafe']), ['Cafe', 'Café']);
    });

    test('sorts the sharp s like ss', () {
      expect(sorted(['Strasse', 'Straße', 'Strand']), [
        'Strand',
        'Strasse',
        'Straße',
      ]);
    });
  });

  group('compareBase', () {
    test('ignores case and accents completely', () {
      expect(compareBase('Café', 'cafe'), 0);
      expect(compareBase('Über', 'uber'), 0);
    });

    test('still orders different letters', () {
      expect(compareBase('éco-op', 'zombies'), lessThan(0));
    });
  });

  group('stableSorted', () {
    test('keeps the input order of entries that compare equal', () {
      final items = List.generate(100, (i) => (i, i % 3));

      final result = stableSorted(items, (a, b) => a.$2.compareTo(b.$2));

      for (var group = 0; group < 3; group++) {
        final ids = result.where((r) => r.$2 == group).map((r) => r.$1);
        expect(ids.toList(), [...ids]..sort());
      }
    });

    test('does not change the input', () {
      final items = [3, 1, 2];

      stableSorted(items, (a, b) => a.compareTo(b));

      expect(items, [3, 1, 2]);
    });
  });
}
