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

    test('the control shows the partner or "Shared space"', () {
      expect(shared.controlLabel, 'alex');
      expect(alone.controlLabel, 'Shared space');
      expect(waiting.controlLabel, 'Shared space');
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

    test('leaving cancels the invitation while one is pending', () {
      expect(shared.leaveLabel, 'Leave space');
      expect(alone.leaveLabel, 'Leave space');
      expect(waiting.leaveLabel, 'Cancel invitation');
    });

    test('the header caption', () {
      expect(shared.caption, 'with alex - ratings and playtime stay your own');
      expect(alone.caption, 'ratings and playtime stay your own');
    });

    test('the waiting line', () {
      expect(waiting.waitingLine, 'Waiting for alex to accept your invitation');
      expect(shared.waitingLine, isNull);
    });

    test('the invitation names who invited', () {
      expect(
        space('invited', const [partner, me]).invitationTitle,
        'alex invited you to a shared space',
      );
      expect(
        space('invited', const []).invitationTitle,
        'Someone invited you to a shared space',
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

    test('only Steam games can be shared', () {
      expect(canShareToSpace(steam), isTrue);
      expect(canShareToSpace(const BacklogEntry(id: 2, title: 'x')), isFalse);
      expect(
        shareToSpaceHint,
        'Only Steam games can be added to the shared space',
      );
    });

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
        'Added "Portal 2" to your shared space',
      );
    });
  });
}
