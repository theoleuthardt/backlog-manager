import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/space.dart';
import 'package:flutter_test/flutter_test.dart';

const me = SpaceMember(username: 'theo', status: 'active', isMe: true);
const partner = SpaceMember(username: 'alex', status: 'active', isMe: false);
const invitedPartner = SpaceMember(
  username: 'alex',
  status: 'invited',
  isMe: false,
);

Space space(String? myStatus, List<SpaceMember> members, {int? id = 4}) =>
    Space(spaceId: id, myStatus: myStatus, members: members);

void main() {
  group('spaceEntryFor', () {
    const personal = BacklogEntry(id: 1, title: 'Portal 2', steamAppId: 620);

    test('is the entry of the space with the same Steam App ID', () {
      final found = spaceEntryFor(personal, const [
        BacklogEntry(id: 7, title: 'Other', steamAppId: 5),
        BacklogEntry(id: 8, title: 'Portal Two', steamAppId: 620),
      ]);

      expect(found?.id, 8);
    });

    test('matches a game without Steam App ID by its title', () {
      final found = spaceEntryFor(
        const BacklogEntry(id: 1, title: 'Custom Game'),
        const [
          BacklogEntry(id: 3, title: 'Another'),
          BacklogEntry(id: 4, title: '  custom GAME '),
        ],
      );

      expect(found?.id, 4);
    });

    test('does not match by title when the game has a Steam App ID', () {
      expect(
        spaceEntryFor(personal, const [
          BacklogEntry(id: 3, title: 'Portal 2', steamAppId: 5),
        ]),
        isNull,
      );
    });

    test('is null when the space does not have the game', () {
      expect(spaceEntryFor(personal, const []), isNull);
    });
  });

  group('stage', () {
    test('no space, invited and active', () {
      expect(space(null, const [], id: null).stage, SpaceStage.none);
      expect(space('invited', const [partner]).stage, SpaceStage.invited);
      expect(space('active', const [me]).stage, SpaceStage.active);
    });

    test('only an active member has a space to show', () {
      expect(space('active', const [me]).activeSpaceId, 4);
      expect(space('invited', const [partner]).activeSpaceId, isNull);
      expect(space(null, const [], id: null).activeSpaceId, isNull);
    });
  });

  group('the partner', () {
    test('is the member who is not me', () {
      expect(space('active', const [me, partner]).partner?.username, 'alex');
    });

    test('is missing while nobody was invited', () {
      expect(space('active', const [me]).partner, isNull);
      expect(space('active', const [me]).needsInvitation, isTrue);
    });

    test('a pending invitation is waiting for the partner', () {
      final info = space('active', const [me, invitedPartner]);

      expect(info.waitingForPartner, isTrue);
      expect(info.partnerIsActive, isFalse);
      expect(info.needsInvitation, isFalse);
    });

    test('an active partner is not waited for', () {
      final info = space('active', const [me, partner]);

      expect(info.partnerIsActive, isTrue);
      expect(info.waitingForPartner, isFalse);
    });
  });

  group('labels', () {
    final shared = space('active', const [me, partner]);
    final alone = space('active', const [me]);
    final waiting = space('active', const [me, invitedPartner]);

    test('the control shows the partner or "Shared Space"', () {
      expect(shared.controlLabel, 'alex');
      expect(alone.controlLabel, 'Shared Space');
      expect(waiting.controlLabel, 'Shared Space');
    });

    test('the info text says who the space is shared with', () {
      expect(
        shared.infoText,
        'Shared with alex. Status and categories are shared; rating and '
        'playtime stay your own.',
      );
      expect(
        alone.infoText,
        'A shared co-op backlog for two. Status and categories are shared; '
        'rating and playtime stay your own.',
      );
    });

    test('the waiting line', () {
      expect(waiting.waitingLine, 'Waiting for alex to accept your invitation');
      expect(shared.waitingLine, isNull);
    });

    test('the invitation names who invited', () {
      expect(
        space('invited', const [partner, me]).invitationTitle,
        'alex invited you to a Shared Space',
      );
      expect(
        space('invited', const []).invitationTitle,
        'Someone invited you to a Shared Space',
      );
    });
  });

  group('initials and progress', () {
    test('initials are the first two letters in capitals', () {
      expect(memberInitials('theo'), 'TH');
      expect(memberInitials('a'), 'A');
      expect(memberInitials(''), '?');
    });

    test('hours of a member as shown beside the bar', () {
      expect(memberHoursLabel(12), '12 h');
      expect(memberHoursLabel(8.5), '8.5 h');
      expect(memberHoursLabel(null), '0 h');
    });

    test('the number of shared games', () {
      expect(sharedGamesLabel(1), '1 shared game');
      expect(sharedGamesLabel(14), '14 shared games');
    });
  });

  group('the invitation form', () {
    test('trims the name and refuses a blank one', () {
      expect(inviteName('  alex '), 'alex');
      expect(inviteName('   '), isNull);
    });

    test('the confirmation of leaving', () {
      expect(
        leaveWarning,
        'You lose access to its entries. They stay with your partner; once '
        'nobody is left they are deleted.',
      );
    });
  });

  group('sharing a game', () {
    const steam = BacklogEntry(
      id: 1,
      title: 'It Takes Two',
      imageLink: 'https://img/it.jpg',
      genre: ['Co-op'],
      platform: ['PC'],
      status: 'Playing',
      owned: true,
      interest: 3,
      reviewStars: 9,
      review: 'Fun',
      note: 'with alex',
      description: 'Two players',
      trailerLink: 'https://youtu.be/x',
      mainTime: 14,
      mainPlusExtraTime: 16,
      completionTime: 20,
      playtime: 6.5,
      steamAppId: 1426210,
    );

    test('the copy keeps every field of the game', () {
      final copy = sharedCopyOf(steam);

      expect(copy.title, 'It Takes Two');
      expect(copy.imageLink, 'https://img/it.jpg');
      expect(copy.genre, ['Co-op']);
      expect(copy.platform, ['PC']);
      expect(copy.status, 'Playing');
      expect(copy.owned, isTrue);
      expect(copy.interest, 3);
      expect(copy.reviewStars, 9);
      expect(copy.review, 'Fun');
      expect(copy.note, 'with alex');
      expect(copy.description, 'Two players');
      expect(copy.trailerLink, 'https://youtu.be/x');
      expect(copy.mainTime, 14);
      expect(copy.mainPlusExtraTime, 16);
      expect(copy.completionTime, 20);
      expect(copy.playtime, 6.5);
      expect(copy.steamAppId, 1426210);
    });

    test('a game without cover or playtime copies without them', () {
      final copy = sharedCopyOf(
        const BacklogEntry(id: 3, title: 'x', steamAppId: 5),
      );

      expect(copy.imageLink, isNull);
      expect(copy.playtime, 0);
    });

    test('the toast names the game', () {
      expect(
        sharedToastMessage('Portal 2'),
        'Added "Portal 2" to your Shared Space',
      );
    });
  });
}
