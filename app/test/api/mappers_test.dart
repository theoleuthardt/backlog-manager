import 'package:backlog_manager/api/generated/export.dart';
import 'package:backlog_manager/api/mappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toNumber', () {
    test('parses decimal strings', () {
      expect(toNumber('12.5'), 12.5);
      expect(toNumber('4'), 4);
    });

    test('returns null for missing or unparsable values', () {
      expect(toNumber(null), isNull);
      expect(toNumber(''), isNull);
      expect(toNumber('abc'), isNull);
      expect(toNumber('NaN'), isNull);
      expect(toNumber('Infinity'), isNull);
    });
  });

  group('entryFromResponse', () {
    final response = BacklogEntryResponse(
      id: 7,
      title: 'Hades',
      genre: const ['Roguelike'],
      platform: const ['PC'],
      status: 'Playing',
      owned: true,
      interest: 4,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      mainTime: '21.5',
      playtime: '30',
      partnerPlaytime: 'oops',
      reviewStars: 9,
      steamAppId: 1145360,
    );

    test('maps the wire values to the app entry', () {
      final entry = entryFromResponse(response);

      expect(entry.id, 7);
      expect(entry.title, 'Hades');
      expect(entry.imageLink, '');
      expect(entry.imageAlt, 'Hades');
      expect(entry.mainTime, 21.5);
      expect(entry.playtime, 30);
      expect(entry.partnerPlaytime, isNull);
      expect(entry.reviewStars, 9);
      expect(entry.steamAppId, 1145360);
      expect(entry.inSharedSpace, isFalse);
    });
  });

  group('categoryFromResponse', () {
    test('keeps the description nullable', () {
      final category = categoryFromResponse(
        const CategoryResponse(id: 1, name: 'Co-op', color: '#38bdf8'),
      );

      expect(category.name, 'Co-op');
      expect(category.description, isNull);
    });
  });

  group('spaceFromResponse', () {
    test('maps the members and my status', () {
      final space = spaceFromResponse(
        const SpaceResponse(
          spaceId: 3,
          myStatus: 'active',
          members: [
            SpaceMemberResponse(username: 'me', status: 'active', isMe: true),
            SpaceMemberResponse(
              username: 'friend',
              status: 'invited',
              isMe: false,
            ),
          ],
        ),
      );

      expect(space.spaceId, 3);
      expect(space.myStatus, 'active');
      expect(space.members.map((m) => m.username), ['me', 'friend']);
      expect(space.members.first.isMe, isTrue);
    });
  });
}
