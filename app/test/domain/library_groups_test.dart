import 'package:backlog_manager/domain/library_groups.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/sort_entries.dart';
import 'package:flutter_test/flutter_test.dart';

const statuses = [
  'Not Started',
  'In Progress',
  'Completed',
  'On Hold',
  'Dropped',
];

BacklogEntry game(
  int id,
  String title, {
  String status = 'Not Started',
  double? playtime,
  List<String> genre = const [],
}) => BacklogEntry(
  id: id,
  title: title,
  status: status,
  playtime: playtime,
  genre: genre,
);

List<String> labels(List<LibraryGroup> groups) => [
  for (final group in groups) group.label,
];

List<String> titles(LibraryGroup group) => [
  for (final entry in group.entries) entry.title,
];

SortConfig config(
  SortOption sortBy, {
  SortDirection? direction,
  List<String> statusOrder = statuses,
  Map<int, String>? categories,
}) => SortConfig(
  sortBy: sortBy,
  direction: direction ?? defaultDirectionFor(sortBy),
  statusOrder: statusOrder,
  categoryByEntryId: categories,
);

void main() {
  group('by status', () {
    final entries = [
      game(1, 'Celeste'),
      game(2, 'Hades', status: 'Completed'),
      game(3, 'Tunic', status: 'Imported'),
    ];

    test('gives every status a group, empty ones included, and the unknown ones last', () {
      final groups = buildLibraryGroups(
        entries: entries,
        config: config(SortOption.status),
      );

      expect(labels(groups), [...statuses, 'Imported']);
      expect(groups.every((g) => g.status == g.label), isTrue);
      expect(titles(groups.first), ['Celeste']);
      expect(groups[1].entries, isEmpty);
    });

    test('reverses the order of the groups for a descending sort', () {
      final groups = buildLibraryGroups(
        entries: entries,
        config: config(
          SortOption.status,
          direction: SortDirection.desc,
          statusOrder: [...statuses, 'Imported'],
        ),
      );

      expect(labels(groups), ['Imported', ...statuses.reversed]);
    });

    test('shows only the selected groups when a status filter is set', () {
      final groups = buildLibraryGroups(
        entries: entries,
        config: config(SortOption.status),
        statusFilter: {'Completed', 'Not Started'},
      );

      expect(labels(groups), ['Not Started', 'Completed']);
    });

    test('keeps every group for an empty status filter', () {
      final groups = buildLibraryGroups(
        entries: entries,
        config: config(SortOption.status),
        statusFilter: {},
      );

      expect(groups, hasLength(6));
    });

    test('includes the custom statuses of the user in their place', () {
      final groups = buildLibraryGroups(
        entries: [game(1, 'Celeste', status: 'Wishlist')],
        config: config(
          SortOption.status,
          statusOrder: [...statuses, 'Wishlist'],
        ),
      );

      expect(labels(groups).last, 'Wishlist');
      expect(titles(groups.last), ['Celeste']);
    });
  });

  group('by another sort option', () {
    test(
      'groups by playtime bucket in the sort order, descending by default',
      () {
        final groups = buildLibraryGroups(
          entries: [
            game(1, 'A', playtime: 5),
            game(2, 'B', playtime: 120),
            game(3, 'C'),
            game(4, 'D', playtime: 20),
          ],
          config: config(SortOption.playtime),
        );

        expect(labels(groups), [
          '100h or more',
          '10-50h',
          'Under 10h',
          'Not played',
        ]);
        expect(groups.every((g) => g.status == null), isTrue);
      },
    );

    test('groups by first genre and puts entries without one last', () {
      final groups = buildLibraryGroups(
        entries: [
          game(1, 'A', genre: ['RPG', 'Action']),
          game(2, 'B'),
          game(3, 'C', genre: ['Action']),
        ],
        config: config(SortOption.genre),
      );

      expect(labels(groups), ['Action', 'RPG', 'No genre']);
    });

    test(
      'shows the categories that have no game after the others, by name',
      () {
        final groups = buildLibraryGroups(
          entries: [game(1, 'A'), game(2, 'B')],
          config: config(SortOption.category, categories: {1: 'Co-op'}),
          categoryNames: ['Zebra', 'Co-op', 'Backlog'],
        );

        expect(labels(groups), ['Co-op', 'Uncategorized', 'Backlog', 'Zebra']);
        expect(groups[2].entries, isEmpty);
      },
    );

    test('has no groups for no entries', () {
      expect(
        buildLibraryGroups(entries: const [], config: config(SortOption.genre)),
        isEmpty,
      );
    });
  });

  group('the group key', () {
    test('tells groups of the same label apart per sort option', () {
      final byStatus = buildLibraryGroups(
        entries: [game(1, 'A')],
        config: config(SortOption.status),
      ).first;
      final byGenre = buildLibraryGroups(
        entries: [
          game(1, 'A', genre: ['Not Started']),
        ],
        config: config(SortOption.genre),
      ).first;

      expect(byStatus.key, isNot(byGenre.key));
    });
  });

  group('drop targets', () {
    test('every status group is one, empty ones too', () {
      final groups = buildLibraryGroups(
        entries: [game(1, 'A')],
        config: config(SortOption.status),
      );

      expect(groups.every((group) => group.droppable), isTrue);
    });

    test('the categories are, the games without a category are not', () {
      final groups = buildLibraryGroups(
        entries: [game(1, 'A'), game(2, 'B')],
        config: config(SortOption.category, categories: {1: 'RPG'}),
        categoryNames: ['RPG', 'Indie'],
      );

      expect(
        {for (final group in groups) group.label: group.droppable},
        {'RPG': true, 'Uncategorized': false, 'Indie': true},
      );
    });

    test('the other sort options have none', () {
      final groups = buildLibraryGroups(
        entries: [
          game(1, 'A', genre: ['RPG']),
        ],
        config: config(SortOption.genre),
      );

      expect(groups.any((group) => group.droppable), isFalse);
    });
  });
}
