import 'package:backlog_manager/domain/filter_entries.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

BacklogEntry entry({
  int id = 1,
  String title = 'Untitled',
  List<String> genre = const [],
  List<String> platform = const [],
  String status = 'Not Started',
  bool owned = false,
  int interest = 0,
  int? reviewStars,
  double? playtime,
  double? mainTime,
  double? mainPlusExtraTime,
  double? completionTime,
}) {
  return BacklogEntry(
    id: id,
    title: title,
    genre: genre,
    platform: platform,
    status: status,
    owned: owned,
    interest: interest,
    reviewStars: reviewStars,
    playtime: playtime,
    mainTime: mainTime,
    mainPlusExtraTime: mainPlusExtraTime,
    completionTime: completionTime,
  );
}

List<int> ids(List<BacklogEntry> entries) => entries.map((e) => e.id).toList();

void main() {
  group('filterEntries', () {
    test('keeps every entry when no filter is active, including zero and very high values', () {
      final entries = [
        entry(id: 1, interest: 0, reviewStars: 0, playtime: 0),
        entry(id: 2, interest: 10, reviewStars: 5, playtime: 900),
      ];

      expect(ids(filterEntries(entries, emptyFilters)), [1, 2]);
    });

    test('matches the search text against the title, case-insensitively', () {
      final entries = [
        entry(id: 1, title: 'Hollow Knight'),
        entry(id: 2, title: 'Celeste'),
      ];

      expect(
        ids(filterEntries(entries, const EntryFilters(search: '  KNIGHT '))),
        [1],
      );
    });

    test('keeps entries that share at least one selected platform', () {
      final entries = [
        entry(id: 1, platform: ['PC', 'Switch']),
        entry(id: 2, platform: ['PS5']),
        entry(id: 3),
      ];

      expect(
        ids(
          filterEntries(
            entries,
            const EntryFilters(platforms: ['Switch', 'Xbox']),
          ),
        ),
        [1],
      );
    });

    test('keeps entries that share at least one selected genre', () {
      final entries = [
        entry(id: 1, genre: ['RPG']),
        entry(id: 2, genre: ['Puzzle', 'Action']),
      ];

      expect(
        ids(filterEntries(entries, const EntryFilters(genres: ['Action']))),
        [2],
      );
    });

    test('keeps entries whose status is one of the selected statuses', () {
      final entries = [
        entry(id: 1, status: 'Completed'),
        entry(id: 2, status: 'Dropped'),
      ];

      expect(
        ids(filterEntries(entries, const EntryFilters(statuses: ['Dropped']))),
        [2],
      );
    });

    test('drops unowned entries when ownedOnly is set', () {
      final entries = [entry(id: 1, owned: true), entry(id: 2)];

      expect(ids(filterEntries(entries, const EntryFilters(ownedOnly: true))), [
        1,
      ]);
    });

    test('applies an interest range inclusively', () {
      final entries = [
        entry(id: 1, interest: 2),
        entry(id: 2, interest: 5),
        entry(id: 3, interest: 8),
      ];

      expect(
        ids(filterEntries(entries, const EntryFilters(interest: (5, 8)))),
        [2, 3],
      );
    });

    test('lets entries without a review through a review-stars range but filters rated ones', () {
      final entries = [
        entry(id: 1),
        entry(id: 2, reviewStars: 2),
        entry(id: 3, reviewStars: 5),
      ];

      expect(
        ids(filterEntries(entries, const EntryFilters(reviewStars: (4, 5)))),
        [1, 3],
      );
    });

    test('treats a cleared (0) review the same as never rated for the review-stars range', () {
      final entries = [
        entry(id: 1, reviewStars: 0),
        entry(id: 2, reviewStars: 2),
      ];

      expect(
        ids(filterEntries(entries, const EntryFilters(reviewStars: (4, 5)))),
        [1],
      );
    });

    test('applies playtime and the three HowLongToBeat ranges', () {
      final entries = [
        entry(
          id: 1,
          playtime: 5,
          mainTime: 10,
          mainPlusExtraTime: 20,
          completionTime: 40,
        ),
        entry(
          id: 2,
          playtime: 50,
          mainTime: 60,
          mainPlusExtraTime: 90,
          completionTime: 150,
        ),
      ];

      expect(
        ids(filterEntries(entries, const EntryFilters(playtime: (0, 10)))),
        [1],
      );
      expect(
        ids(filterEntries(entries, const EntryFilters(mainTime: (30, 100)))),
        [2],
      );
      expect(
        ids(
          filterEntries(
            entries,
            const EntryFilters(mainPlusExtraTime: (0, 30)),
          ),
        ),
        [1],
      );
      expect(
        ids(
          filterEntries(
            entries,
            const EntryFilters(completionTime: (100, 200)),
          ),
        ),
        [2],
      );
    });

    test('combines all active filters with AND', () {
      final entries = [
        entry(id: 1, status: 'Completed', owned: true, platform: ['PC']),
        entry(id: 2, status: 'Completed', platform: ['PC']),
      ];

      final result = filterEntries(
        entries,
        const EntryFilters(
          statuses: ['Completed'],
          ownedOnly: true,
          platforms: ['PC'],
        ),
      );

      expect(ids(result), [1]);
    });
  });

  group('filterEntries by category', () {
    const categories = {
      1: ['Arcade', 'Co-op'],
      2: ['Story'],
    };

    test('keeps entries that have at least one selected category', () {
      final entries = [entry(id: 1), entry(id: 2), entry(id: 3)];

      final result = filterEntries(
        entries,
        const EntryFilters(categories: ['Co-op', 'Story']),
        categories,
      );

      expect(ids(result), [1, 2]);
    });

    test('drops uncategorized entries once a category is selected', () {
      final result = filterEntries(
        [entry(id: 3)],
        const EntryFilters(categories: ['Arcade']),
        categories,
      );

      expect(result, isEmpty);
    });

    test('ignores categories entirely when none is selected', () {
      expect(ids(filterEntries([entry(id: 3)], emptyFilters, categories)), [3]);
    });
  });

  group('countActiveFilters', () {
    test('is zero for the empty filter set', () {
      expect(countActiveFilters(emptyFilters), 0);
    });

    test('counts an active category filter', () {
      expect(countActiveFilters(const EntryFilters(categories: ['Arcade'])), 1);
    });

    test('counts each active filter once and ignores the search text', () {
      const filters = EntryFilters(
        search: 'zelda',
        platforms: ['PC', 'Switch'],
        ownedOnly: true,
        playtime: (0, 10),
      );

      expect(countActiveFilters(filters), 3);
    });
  });
}
