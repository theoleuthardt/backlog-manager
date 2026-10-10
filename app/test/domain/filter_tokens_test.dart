import 'package:backlog_manager/domain/filter_entries.dart';
import 'package:backlog_manager/domain/filter_tokens.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

BacklogEntry entry({
  int id = 1,
  List<String> genre = const [],
  List<String> platform = const [],
  double? playtime,
  double? mainTime,
  double? mainPlusExtraTime,
  double? completionTime,
}) {
  return BacklogEntry(
    id: id,
    title: 'Game $id',
    genre: genre,
    platform: platform,
    playtime: playtime,
    mainTime: mainTime,
    mainPlusExtraTime: mainPlusExtraTime,
    completionTime: completionTime,
  );
}

void main() {
  group('FilterField', () {
    test('has the labels of the filter menu in its order', () {
      expect(FilterField.values.map((field) => field.label), [
        'Platform',
        'Genre',
        'Status',
        'Category',
        'Interest',
        'Review stars',
        'Playtime',
        'Main story',
        'Main + extra',
        'Completionist',
      ]);
    });

    test('knows its lists, its ranges and the hour ranges', () {
      expect(FilterField.status.isRange, isFalse);
      expect(FilterField.interest.isRange, isTrue);
      expect(FilterField.interest.unit, '');
      expect(FilterField.reviewStars.unit, '');
      expect(FilterField.playtime.unit, ' h');
      expect(FilterField.completionTime.unit, ' h');
    });
  });

  group('filterTokens', () {
    test(
      'is empty for the empty filters and ignores search and owned only',
      () {
        expect(filterTokens(emptyFilters), isEmpty);
        expect(
          filterTokens(const EntryFilters(search: 'zelda', ownedOnly: true)),
          isEmpty,
        );
      },
    );

    test('shows a list filter as its values joined by commas', () {
      final tokens = filterTokens(
        const EntryFilters(
          statuses: ['In Progress', 'On Hold'],
          categories: ['Co-op nights'],
        ),
      );

      expect(tokens.map((token) => (token.field, token.value)), [
        (FilterField.status, 'In Progress, On Hold'),
        (FilterField.category, 'Co-op nights'),
      ]);
    });

    test('shows a range as "min to max" with the unit of its field', () {
      final tokens = filterTokens(
        const EntryFilters(
          interest: (3, 8),
          reviewStars: (0, 7),
          playtime: (12, 62),
          mainTime: (0.5, 10),
        ),
      );

      expect(tokens.map((token) => '${token.field.label} ${token.value}'), [
        'Interest 3 to 8',
        'Review stars 0 to 7',
        'Playtime 12 to 62 h',
        'Main story 0.5 to 10 h',
      ]);
    });

    test('keeps the order of the fields, not the order of adding them', () {
      final tokens = filterTokens(
        const EntryFilters(
          playtime: (1, 2),
          genres: ['RPG'],
          platforms: ['PC'],
        ),
      );

      expect(tokens.map((token) => token.field), [
        FilterField.platform,
        FilterField.genre,
        FilterField.playtime,
      ]);
    });
  });

  group('changing the filters', () {
    test('sets and replaces a list filter', () {
      final once = setListFilter(emptyFilters, FilterField.genre, ['RPG']);
      final twice = setListFilter(once, FilterField.genre, ['RPG', 'Puzzle']);

      expect(once.genres, ['RPG']);
      expect(twice.genres, ['RPG', 'Puzzle']);
      expect(twice.platforms, isEmpty);
    });

    test('an empty selection removes a list filter', () {
      final filters = setListFilter(emptyFilters, FilterField.status, ['A']);

      expect(setListFilter(filters, FilterField.status, []).statuses, isEmpty);
    });

    test('sets a range and treats the full range as no filter', () {
      final set = setRangeFilter(emptyFilters, FilterField.playtime, (
        5,
        20,
      ), 40);
      final full = setRangeFilter(set, FilterField.playtime, (0, 40), 40);

      expect(set.playtime, (5, 20));
      expect(full.playtime, isNull);
    });

    test('clears one filter and leaves the others', () {
      final filters = const EntryFilters(
        genres: ['RPG'],
        interest: (2, 9),
        playtime: (1, 5),
      );

      final cleared = clearFilter(
        clearFilter(filters, FilterField.genre),
        FilterField.interest,
      );

      expect(cleared.genres, isEmpty);
      expect(cleared.interest, isNull);
      expect(cleared.playtime, (1, 5));
    });

    test('reset clears every filter but keeps the search text', () {
      const filters = EntryFilters(
        search: 'zelda',
        genres: ['RPG'],
        ownedOnly: true,
        mainTime: (1, 2),
      );

      final reset = resetFilters(filters);

      expect(reset.search, 'zelda');
      expect(reset.genres, isEmpty);
      expect(reset.ownedOnly, isFalse);
      expect(reset.mainTime, isNull);
      expect(countActiveFilters(reset), 0);
    });

    test('drops selected categories that no longer exist', () {
      const filters = EntryFilters(categories: ['Co-op', 'Deleted']);

      final kept = dropMissingCategories(filters, ['Co-op', 'Story']);

      expect(kept.categories, ['Co-op']);
      expect(identical(dropMissingCategories(kept, ['Co-op']), kept), isTrue);
    });
  });

  group('filterBounds', () {
    test('uses 10 for interest and the review stars', () {
      final bounds = filterBounds(const []);

      expect(bounds.interest, 10);
      expect(bounds.reviewStars, 10);
    });

    test('is at least 10 hours and rounds the largest value up', () {
      expect(filterBounds(const []).playtime, 10);
      expect(filterBounds([entry(playtime: 4)]).playtime, 10);
      expect(
        filterBounds([entry(playtime: 12.2), entry(id: 2, playtime: 61.4)])
            .playtime,
        62,
      );
    });

    test('takes every time field from its own data', () {
      final bounds = filterBounds([
        entry(mainTime: 11, mainPlusExtraTime: 25.5, completionTime: 80),
      ]);

      expect(bounds.mainTime, 11);
      expect(bounds.mainPlusExtraTime, 26);
      expect(bounds.completionTime, 80);
      expect(bounds.playtime, 10);
    });

    test('exposes the bound of a field', () {
      final bounds = filterBounds([entry(completionTime: 33)]);

      expect(bounds.of(FilterField.completionTime), 33);
      expect(bounds.of(FilterField.interest), 10);
    });
  });

  group('uniqueSorted', () {
    test('lists every value once, sorted like the web client', () {
      expect(uniqueSorted(['rpg', 'Action', 'RPG', 'Action', 'ärger']), [
        'Action',
        'ärger',
        'rpg',
        'RPG',
      ]);
    });
  });
}
