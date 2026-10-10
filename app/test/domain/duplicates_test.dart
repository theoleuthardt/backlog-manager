import 'package:backlog_manager/domain/duplicates.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

BacklogEntry entry(
  int id,
  String title, {
  int? steamAppId,
  String status = 'Playing',
  List<String> platform = const ['PC'],
  double? playtime,
}) => BacklogEntry(
  id: id,
  title: title,
  steamAppId: steamAppId,
  status: status,
  platform: platform,
  playtime: playtime,
);

void main() {
  group('normalizedTitle', () {
    test('ignores case, outer and repeated spaces', () {
      expect(normalizedTitle('  Hades  II '), 'hades ii');
      expect(normalizedTitle('HADES'), normalizedTitle('hades'));
    });
  });

  group('findDuplicateGroups', () {
    test('finds nothing when every title is unique', () {
      expect(
        findDuplicateGroups([entry(1, 'Hades'), entry(2, 'Celeste')]),
        isEmpty,
      );
    });

    test('groups entries with the same title without regard to case', () {
      final groups = findDuplicateGroups([
        entry(1, 'Hades'),
        entry(2, 'Celeste'),
        entry(3, ' hades '),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.entries.map((e) => e.id), [1, 3]);
      expect(groups.single.title, 'Hades');
    });

    test('groups entries with the same Steam App ID', () {
      final groups = findDuplicateGroups([
        entry(1, 'Portal 2', steamAppId: 620),
        entry(2, 'Portal Two', steamAppId: 620),
        entry(3, 'Other', steamAppId: 5),
      ]);

      expect(groups.single.entries.map((e) => e.id), [1, 2]);
      expect(groups.single.sharedSteamAppId, isTrue);
      expect(groups.single.sharedTitle, isFalse);
    });

    test('joins entries linked by title and by Steam App ID', () {
      final groups = findDuplicateGroups([
        entry(1, 'Portal 2', steamAppId: 620),
        entry(2, 'Portal 2'),
        entry(3, 'Portal Two', steamAppId: 620),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.entries.map((e) => e.id), [1, 2, 3]);
      expect(groups.single.sharedTitle, isTrue);
      expect(groups.single.sharedSteamAppId, isTrue);
    });

    test('keeps separate games apart and orders groups by title', () {
      final groups = findDuplicateGroups([
        entry(1, 'Zelda'),
        entry(2, 'Zelda'),
        entry(3, 'Alpha'),
        entry(4, 'alpha'),
      ]);

      expect(groups.map((g) => g.title), ['Alpha', 'Zelda']);
    });

    test('orders the entries of a group by id', () {
      final groups = findDuplicateGroups([
        entry(9, 'Hades'),
        entry(2, 'Hades'),
        entry(5, 'Hades'),
      ]);

      expect(groups.single.entries.map((e) => e.id), [2, 5, 9]);
    });

    test('ignores entries without a Steam App ID for the id link', () {
      expect(findDuplicateGroups([entry(1, 'A'), entry(2, 'B')]), isEmpty);
    });
  });

  group('labels', () {
    test('the reason names what the games share', () {
      final byTitle = findDuplicateGroups([entry(1, 'A'), entry(2, 'a')])
          .single;
      final byId = findDuplicateGroups([
        entry(1, 'A', steamAppId: 1),
        entry(2, 'B', steamAppId: 1),
      ]).single;
      final both = findDuplicateGroups([
        entry(1, 'A', steamAppId: 1),
        entry(2, 'a', steamAppId: 1),
      ]).single;

      expect(byTitle.reason, 'Same title');
      expect(byId.reason, 'Same Steam App ID');
      expect(both.reason, 'Same title and Steam App ID');
    });

    test('the heading counts the groups and the games', () {
      expect(duplicatesHeading(0, 0), 'No duplicates found');
      expect(
        duplicatesHeading(1, 2),
        '1 game is in your backlog more than once (2 entries)',
      );
      expect(
        duplicatesHeading(3, 7),
        '3 games are in your backlog more than once (7 entries)',
      );
    });
  });

  group('diffAgainst', () {
    test('lists what differs from the kept entry', () {
      final kept = entry(1, 'Hades', status: 'Completed', playtime: 20);
      final other = entry(
        2,
        'Hades',
        status: 'Playing',
        platform: const ['Switch'],
        playtime: 20,
      );

      final diffs = diffAgainst(kept, other);

      expect(diffs.map((d) => d.field), ['platform', 'status']);
      expect(diffs.first.existing, 'PC');
      expect(diffs.first.proposed, 'Switch');
    });

    test('is empty for identical entries', () {
      expect(diffAgainst(entry(1, 'A'), entry(2, 'A')), isEmpty);
    });
  });
}
