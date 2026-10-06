import 'package:backlog_manager/domain/group_entries.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/sort_entries.dart';
import 'package:flutter_test/flutter_test.dart';

const statusOrder = [
  'Not Started',
  'In Progress',
  'Completed',
  'On Hold',
  'Dropped',
];

BacklogEntry entry({
  int id = 1,
  String title = 'Untitled',
  List<String> genre = const [],
  List<String> platform = const [],
  String status = 'Not Started',
  int interest = 0,
  int? reviewStars,
  double? playtime,
}) {
  return BacklogEntry(
    id: id,
    title: title,
    genre: genre,
    platform: platform,
    status: status,
    interest: interest,
    reviewStars: reviewStars,
    playtime: playtime,
  );
}

List<String> titles(List<BacklogEntry> entries) =>
    entries.map((e) => e.title).toList();

SortConfig config(
  SortOption sortBy,
  SortDirection direction, {
  Map<int, String>? categoryByEntryId,
}) {
  return SortConfig(
    sortBy: sortBy,
    direction: direction,
    statusOrder: statusOrder,
    categoryByEntryId: categoryByEntryId,
  );
}

void main() {
  group('sortEntries', () {
    test('orders by status following the given status order, then title', () {
      final entries = [
        entry(id: 1, title: 'Zelda', status: 'Completed'),
        entry(id: 2, title: 'Alpha', status: 'Not Started'),
        entry(id: 3, title: 'Bravo', status: 'Completed'),
        entry(id: 4, title: 'Doom', status: 'In Progress'),
      ];

      final sorted = sortEntries(
        entries,
        config(SortOption.status, SortDirection.asc),
      );

      expect(titles(sorted), ['Alpha', 'Doom', 'Bravo', 'Zelda']);
    });

    test('places unknown statuses after every known one', () {
      final entries = [
        entry(id: 1, title: 'Custom', status: 'Co-Op Night'),
        entry(id: 2, title: 'Known', status: 'Dropped'),
      ];

      final sorted = sortEntries(
        entries,
        config(SortOption.status, SortDirection.asc),
      );

      expect(titles(sorted), ['Known', 'Custom']);
    });

    test('reverses status order when descending', () {
      final entries = [
        entry(id: 1, title: 'A', status: 'Not Started'),
        entry(id: 2, title: 'B', status: 'Dropped'),
      ];

      final sorted = sortEntries(
        entries,
        config(SortOption.status, SortDirection.desc),
      );

      expect(titles(sorted), ['B', 'A']);
    });

    test('sorts playtime numerically and keeps entries without playtime last in both directions', () {
      final entries = [
        entry(id: 1, title: 'Ten', playtime: 10),
        entry(id: 2, title: 'None'),
        entry(id: 3, title: 'Hundred', playtime: 100),
        entry(id: 4, title: 'Two', playtime: 2),
      ];

      final asc = sortEntries(
        entries,
        config(SortOption.playtime, SortDirection.asc),
      );
      final desc = sortEntries(
        entries,
        config(SortOption.playtime, SortDirection.desc),
      );

      expect(titles(asc), ['Two', 'Ten', 'Hundred', 'None']);
      expect(titles(desc), ['Hundred', 'Ten', 'Two', 'None']);
    });

    test('sorts by interest level', () {
      final entries = [
        entry(id: 1, title: 'Low', interest: 2),
        entry(id: 2, title: 'High', interest: 9),
      ];

      final sorted = sortEntries(
        entries,
        config(SortOption.interest, SortDirection.desc),
      );

      expect(titles(sorted), ['High', 'Low']);
    });

    test('sorts by review stars with unreviewed entries last', () {
      final entries = [
        entry(id: 1, title: 'Unreviewed'),
        entry(id: 2, title: 'Three', reviewStars: 3),
        entry(id: 3, title: 'Five', reviewStars: 5),
      ];

      final sorted = sortEntries(
        entries,
        config(SortOption.reviewStars, SortDirection.desc),
      );

      expect(titles(sorted), ['Five', 'Three', 'Unreviewed']);
    });

    test('treats a cleared (0) review as missing, same as never rated', () {
      final entries = [
        entry(id: 1, title: 'Cleared', reviewStars: 0),
        entry(id: 2, title: 'NeverRated'),
        entry(id: 3, title: 'OneStar', reviewStars: 1),
      ];

      final ascending = titles(
        sortEntries(entries, config(SortOption.reviewStars, SortDirection.asc)),
      );

      expect(ascending.first, 'OneStar');
      expect(ascending.skip(1), containsAll(['Cleared', 'NeverRated']));
    });

    test('sorts by first genre alphabetically, empty genre last', () {
      final entries = [
        entry(id: 1, title: 'NoGenre'),
        entry(id: 2, title: 'Rpg', genre: ['RPG', 'Action']),
        entry(id: 3, title: 'Adventure', genre: ['Adventure']),
      ];

      final sorted = sortEntries(
        entries,
        config(SortOption.genre, SortDirection.asc),
      );

      expect(titles(sorted), ['Adventure', 'Rpg', 'NoGenre']);
    });

    test('sorts by first platform alphabetically, empty platform last', () {
      final entries = [
        entry(id: 1, title: 'NoPlatform'),
        entry(id: 2, title: 'Switch', platform: ['Switch']),
        entry(id: 3, title: 'Pc', platform: ['PC', 'Switch']),
      ];

      final sorted = sortEntries(
        entries,
        config(SortOption.platform, SortDirection.asc),
      );

      expect(titles(sorted), ['Pc', 'Switch', 'NoPlatform']);
    });

    test('sorts by category name with uncategorized entries last', () {
      final entries = [
        entry(id: 1, title: 'Loose'),
        entry(id: 2, title: 'InZ'),
        entry(id: 3, title: 'InA'),
      ];

      final sorted = sortEntries(
        entries,
        config(
          SortOption.category,
          SortDirection.asc,
          categoryByEntryId: {2: 'Zombies', 3: 'Arcade'},
        ),
      );

      expect(titles(sorted), ['InA', 'InZ', 'Loose']);
    });

    test('keeps the input order of entries that tie completely', () {
      final entries = [
        for (var id = 0; id < 100; id++) entry(id: id, title: 'Same title'),
      ];

      final sorted = sortEntries(
        entries,
        config(SortOption.status, SortDirection.asc),
      );

      expect(sorted.map((e) => e.id), List.generate(100, (id) => id));
    });

    test('sorts umlauts with their base letter', () {
      final entries = [
        entry(id: 1, title: 'Zelda'),
        entry(id: 2, title: 'Ärger im Paradies'),
        entry(id: 3, title: 'Anno'),
      ];

      final sorted = sortEntries(
        entries,
        config(SortOption.status, SortDirection.asc),
      );

      expect(titles(sorted), ['Anno', 'Ärger im Paradies', 'Zelda']);
    });

    test('does not mutate the input list', () {
      final entries = [
        entry(id: 1, title: 'B', interest: 1),
        entry(id: 2, title: 'A', interest: 5),
      ];
      final snapshot = [...entries];

      sortEntries(entries, config(SortOption.interest, SortDirection.desc));

      expect(entries, snapshot);
    });
  });

  group('defaultDirectionFor', () {
    const expected = {
      SortOption.status: SortDirection.asc,
      SortOption.category: SortDirection.asc,
      SortOption.genre: SortDirection.asc,
      SortOption.platform: SortDirection.asc,
      SortOption.playtime: SortDirection.desc,
      SortOption.interest: SortDirection.desc,
      SortOption.reviewStars: SortDirection.desc,
    };
    for (final item in expected.entries) {
      test('uses ${item.key.value} -> ${item.value.name}', () {
        expect(defaultDirectionFor(item.key), item.value);
      });
    }
  });

  group('parseSortOption', () {
    test('accepts known options and rejects everything else', () {
      expect(parseSortOption('review_stars'), SortOption.reviewStars);
      expect(parseSortOption('random'), isNull);
    });
  });

  group('groupEntriesByStatus', () {
    test('returns one group per status in the given order, keeping entry order inside each group', () {
      final groups = groupEntriesByStatus(
        [
          entry(id: 1, status: 'Completed'),
          entry(id: 2, status: 'Not Started'),
          entry(id: 3, status: 'Completed'),
        ],
        ['Not Started', 'Completed'],
      );

      expect(groups.map((g) => g.status), ['Not Started', 'Completed']);
      expect(groups[1].entries.map((e) => e.id), [1, 3]);
    });

    test('keeps known statuses without entries as empty groups so they stay drop targets', () {
      final groups = groupEntriesByStatus(
        [entry(id: 1, status: 'Completed')],
        ['Not Started', 'Completed'],
      );

      expect(groups[0].status, 'Not Started');
      expect(groups[0].entries, isEmpty);
    });

    test('appends groups for statuses missing from the given order', () {
      final groups = groupEntriesByStatus(
        [
          entry(id: 1, status: 'Completed'),
          entry(id: 2, status: 'Co-Op Night'),
        ],
        ['Completed'],
      );

      expect(groups.map((g) => g.status), ['Completed', 'Co-Op Night']);
    });
  });

  group('groupLabelFor', () {
    test('labels by first platform or a fallback', () {
      expect(
        groupLabelFor(entry(platform: ['PC', 'Switch']), SortOption.platform),
        'PC',
      );
      expect(groupLabelFor(entry(), SortOption.platform), 'No platform');
    });

    test('labels by first genre or a fallback', () {
      expect(
        groupLabelFor(entry(genre: ['RPG', 'Action']), SortOption.genre),
        'RPG',
      );
      expect(groupLabelFor(entry(), SortOption.genre), 'No genre');
    });

    test('labels by category name or Uncategorized', () {
      const categories = {7: 'Arcade'};

      expect(
        groupLabelFor(entry(id: 7), SortOption.category, categories),
        'Arcade',
      );
      expect(
        groupLabelFor(entry(id: 8), SortOption.category, categories),
        'Uncategorized',
      );
    });

    test('labels by interest level', () {
      expect(
        groupLabelFor(entry(interest: 9), SortOption.interest),
        'Interest 9/10',
      );
    });

    test('labels review stars, treating 0 and missing as Unreviewed', () {
      expect(
        groupLabelFor(entry(reviewStars: 4), SortOption.reviewStars),
        '4 stars',
      );
      expect(
        groupLabelFor(entry(reviewStars: 1), SortOption.reviewStars),
        '1 star',
      );
      expect(
        groupLabelFor(entry(reviewStars: 0), SortOption.reviewStars),
        'Unreviewed',
      );
      expect(groupLabelFor(entry(), SortOption.reviewStars), 'Unreviewed');
    });

    const buckets = <(double?, String)>[
      (null, 'Not played'),
      (0, 'Not played'),
      (5, 'Under 10h'),
      (10, '10-50h'),
      (49, '10-50h'),
      (50, '50-100h'),
      (100, '100h or more'),
    ];
    for (final (playtime, label) in buckets) {
      test('buckets $playtime hours of playtime as $label', () {
        expect(
          groupLabelFor(entry(playtime: playtime), SortOption.playtime),
          label,
        );
      });
    }
  });

  group('groupSortedEntries', () {
    test('groups by label in order of first appearance and merges non-adjacent matches', () {
      final sorted = [
        entry(id: 1, reviewStars: 0),
        entry(id: 2, reviewStars: 3),
        entry(id: 3),
      ];

      final groups = groupSortedEntries(sorted, SortOption.reviewStars);

      expect(groups.map((g) => g.label), ['Unreviewed', '3 stars']);
      expect(groups[0].entries.map((e) => e.id), [1, 3]);
    });
  });
}
