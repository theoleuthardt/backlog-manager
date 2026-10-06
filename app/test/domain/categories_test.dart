import 'package:backlog_manager/domain/categories.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('categoryNameError', () {
    test('accepts a fresh, non-empty name', () {
      expect(categoryNameError('Co-op', ['Story']), '');
    });

    test('stays silent for an empty name so the field is not flagged before typing', () {
      expect(categoryNameError('   ', []), '');
    });

    test('rejects names that are too long', () {
      expect(
        categoryNameError('x' * (categoryNameMaxLength + 1), []),
        matches(RegExp('max', caseSensitive: false)),
      );
    });

    test('rejects duplicates case-insensitively after trimming', () {
      expect(
        categoryNameError('  story ', ['Story']),
        matches(RegExp('already', caseSensitive: false)),
      );
    });
  });

  group('nextCategoryColor', () {
    test('only hands out valid hex colours', () {
      expect(categoryColors.every(isHexColor), isTrue);
    });

    test('cycles through the palette by how many categories exist', () {
      expect(nextCategoryColor(0), categoryColors[0]);
      expect(nextCategoryColor(categoryColors.length), categoryColors[0]);
      expect(nextCategoryColor(1), categoryColors[1]);
    });
  });

  group('sortCategoriesByName', () {
    Category category(int id, String name) =>
        Category(id: id, name: name, color: '#38bdf8');

    test('orders categories alphabetically, ignoring case', () {
      final sorted = sortCategoriesByName([
        category(1, 'story'),
        category(2, 'Co-op'),
        category(3, 'Backlog night'),
      ]);

      expect(sorted.map((c) => c.name), ['Backlog night', 'Co-op', 'story']);
    });

    test('sorts accented names with their base letter', () {
      final sorted = sortCategoriesByName([
        category(1, 'zombies'),
        category(2, 'éco-op'),
        category(3, 'Backlog night'),
      ]);

      expect(sorted.map((c) => c.name), ['Backlog night', 'éco-op', 'zombies']);
    });

    test('keeps the input order of names that only differ in case', () {
      final sorted = sortCategoriesByName([
        category(1, 'Co-op'),
        category(2, 'co-op'),
        category(3, 'CO-OP'),
      ]);

      expect(sorted.map((c) => c.id), [1, 2, 3]);
    });

    test('does not mutate the input', () {
      final input = [category(1, 'b'), category(2, 'a')];

      sortCategoriesByName(input);

      expect(input.map((c) => c.id), [1, 2]);
    });
  });
}
