import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show pumpLibrary;

const me = SpaceMember(username: 'theo', status: 'active', isMe: true);
const partner = SpaceMember(username: 'alex', status: 'active', isMe: false);
const invitedPartner = SpaceMember(
  username: 'alex',
  status: 'invited',
  isMe: false,
);

const noSpace = Space();
const alone = Space(spaceId: 4, myStatus: 'active', members: [me]);
const waiting = Space(
  spaceId: 4,
  myStatus: 'active',
  members: [me, invitedPartner],
);
const together = Space(spaceId: 4, myStatus: 'active', members: [me, partner]);
const invitation = Space(
  spaceId: 4,
  myStatus: 'invited',
  members: [
    partner,
    SpaceMember(username: 'theo', status: 'invited', isMe: true),
  ],
);

class FakeSpaceApi implements SpaceApi {
  FakeSpaceApi(this.space);

  Space space;
  final calls = <String>[];
  Object? inviteError;
  Object? getError;

  @override
  Future<Space> get() async {
    calls.add('get');
    if (getError != null) throw getError!;
    return space;
  }

  @override
  Future<void> invite(String username) async {
    calls.add('invite $username');
    if (inviteError != null) throw inviteError!;
    space = Space(
      spaceId: 4,
      myStatus: 'active',
      members: [
        me,
        SpaceMember(username: username, status: 'invited', isMe: false),
      ],
    );
  }

  @override
  Future<Space> accept() async {
    calls.add('accept');
    space = Space(spaceId: 4, myStatus: 'active', members: [me, partner]);
    return space;
  }

  @override
  Future<void> leave() async {
    calls.add('leave');
    space = noSpace;
  }
}

BacklogEntry shared(
  int id,
  String title, {
  double? mainTime = 10,
  double? playtime = 5,
  double? partnerPlaytime = 2,
  int? steamAppId = 1,
}) => BacklogEntry(
  id: id,
  title: title,
  status: 'Playing',
  mainTime: mainTime,
  playtime: playtime,
  partnerPlaytime: partnerPlaytime,
  steamAppId: steamAppId,
);

class Opened {
  Opened(this.container, this.space, this.backlog, this.games);

  final ProviderContainer container;
  final FakeSpaceApi space;
  final FakeBacklogApi backlog;
  final FakeGamesApi games;

  String get location => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();
}

Future<Opened> open(
  WidgetTester tester,
  Space space, {
  List<BacklogEntry>? entries,
  String location = AppRoutes.space,
  void Function(FakeSpaceApi api)? setUp,
}) async {
  final api = FakeSpaceApi(space);
  setUp?.call(api);
  final backlog = FakeBacklogApi(
    entries: entries ?? [shared(1, 'It Takes Two'), shared(2, 'Portal 2')],
  );
  final games = FakeGamesApi();
  final container = await pumpLibrary(
    tester,
    backlog,
    height: 1100,
    overrides: [
      spaceApiProvider.overrideWithValue(api),
      gamesApiProvider.overrideWithValue(games),
    ],
  );
  container.read(routerProvider).go(location);
  await tester.pumpAndSettle();
  return Opened(container, api, backlog, games);
}

Future<void> dismissToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 6));

DioException apiError(int status, String detail) {
  final options = RequestOptions();
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: {'detail': detail},
    ),
  );
}

void main() {
  group('without a space', () {
    testWidgets('offers to start one', (tester) async {
      await open(tester, noSpace);

      expect(find.byKey(const Key('page-space')), findsOneWidget);
      expect(find.text('Start a shared space'), findsOneWidget);
      expect(
        find.textContaining('only Steam games can be added'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('space-invite-name')), findsOneWidget);
    });

    testWidgets('Invite needs a username', (tester) async {
      final opened = await open(tester, noSpace);

      await tester.enterText(find.byKey(const Key('space-invite-name')), '   ');
      await tester.pump();
      await tester.tap(find.byKey(const Key('space-invite-send')));
      await tester.pump();

      expect(opened.space.calls.where((c) => c.startsWith('invite')), isEmpty);
    });

    testWidgets('sends the invitation and shows the waiting space', (
      tester,
    ) async {
      final opened = await open(tester, noSpace);

      await tester.enterText(
        find.byKey(const Key('space-invite-name')),
        '  alex ',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('space-invite-send')));
      await tester.pumpAndSettle();

      expect(opened.space.calls, contains('invite alex'));
      expect(find.text('Invitation sent to alex'), findsOneWidget);
      expect(find.text('Co-op backlog'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('shows the message of the server when it refuses', (
      tester,
    ) async {
      await open(
        tester,
        noSpace,
        setUp: (api) =>
            api.inviteError = apiError(404, 'No user with that username'),
      );

      await tester.enterText(find.byKey(const Key('space-invite-name')), 'zed');
      await tester.pump();
      await tester.tap(find.byKey(const Key('space-invite-send')));
      await tester.pumpAndSettle();

      expect(find.text('No user with that username'), findsOneWidget);
      expect(find.text('Start a shared space'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('says so when the space cannot be loaded', (tester) async {
      await open(
        tester,
        noSpace,
        setUp: (api) => api.getError = Exception('offline'),
      );

      expect(find.text('Failed to load the shared space'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('with an invitation', () {
    testWidgets('names who invited and offers Accept and Decline', (
      tester,
    ) async {
      await open(tester, invitation);

      expect(find.text('alex invited you to a shared space'), findsOneWidget);
      expect(find.byKey(const Key('space-accept')), findsOneWidget);
      expect(find.byKey(const Key('space-decline')), findsOneWidget);
    });

    testWidgets('Accept opens the space', (tester) async {
      final opened = await open(tester, invitation);

      await tester.tap(find.byKey(const Key('space-accept')));
      await tester.pumpAndSettle();

      expect(opened.space.calls, contains('accept'));
      expect(find.text('Co-op backlog'), findsOneWidget);
      expect(
        find.text('with alex - ratings and playtime stay your own'),
        findsOneWidget,
      );
    });

    testWidgets('Decline leaves, like declining on the web', (tester) async {
      final opened = await open(tester, invitation);

      await tester.tap(find.byKey(const Key('space-decline')));
      await tester.pumpAndSettle();

      expect(opened.space.calls, contains('leave'));
      expect(find.text('Start a shared space'), findsOneWidget);
    });

    testWidgets('puts a dot on the sidebar entry', (tester) async {
      await open(tester, invitation, location: AppRoutes.library);

      expect(find.byKey(const Key('nav-space-invitation')), findsOneWidget);
    });

    testWidgets('no dot without an invitation', (tester) async {
      await open(tester, together, location: AppRoutes.library);

      expect(find.byKey(const Key('nav-space-invitation')), findsNothing);
    });
  });

  group('the space', () {
    testWidgets('loads the entries of the space', (tester) async {
      final opened = await open(tester, together);

      expect(opened.backlog.calls, contains('entries 4'));
      expect(find.text('It Takes Two'), findsWidgets);
      expect(find.text('Portal 2'), findsWidgets);
    });

    testWidgets('shows the header with both members', (tester) async {
      await open(tester, together);

      expect(find.byKey(const Key('space-avatars')), findsOneWidget);
      expect(find.text('TH'), findsWidgets);
      expect(find.text('AL'), findsWidgets);
      expect(find.text('Co-op backlog'), findsOneWidget);
      expect(
        find.text('with alex - ratings and playtime stay your own'),
        findsOneWidget,
      );
      expect(find.text('+ Add Steam game'), findsOneWidget);
      expect(find.byKey(const Key('igdb-sync-button')), findsNothing);
    });

    testWidgets('covers show the progress of both members', (tester) async {
      await open(
        tester,
        together,
        entries: [
          shared(1, 'It Takes Two', playtime: 12, partnerPlaytime: 8.5),
        ],
      );

      expect(find.byKey(const Key('member-progress')), findsOneWidget);
      expect(find.text('12 h'), findsOneWidget);
      expect(find.text('8.5 h'), findsOneWidget);
    });

    testWidgets('a space without an active partner shows only my progress', (
      tester,
    ) async {
      await open(tester, alone);

      expect(find.text('AL'), findsNothing);
      expect(find.text('TH'), findsWidgets);
    });

    testWidgets('invites a partner while there is none', (tester) async {
      final opened = await open(tester, alone);

      expect(find.byKey(const Key('space-invite-name')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('space-invite-name')),
        'alex',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('space-invite-send')));
      await tester.pumpAndSettle();

      expect(opened.space.calls, contains('invite alex'));
      expect(
        find.text('Waiting for alex to accept your invitation.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('space-invite-name')), findsNothing);
      await dismissToast(tester);
    });

    testWidgets('names who the invitation waits for', (tester) async {
      await open(tester, waiting);

      expect(
        find.text('Waiting for alex to accept your invitation.'),
        findsOneWidget,
      );
      expect(find.text('Cancel invitation'), findsOneWidget);
      expect(find.text('Leave'), findsNothing);
    });

    testWidgets('has no invitation notice once the partner is in', (
      tester,
    ) async {
      await open(tester, together);

      expect(find.byKey(const Key('space-waiting')), findsNothing);
      expect(find.byKey(const Key('space-invite-name')), findsNothing);
    });

    testWidgets('Space info explains how the space works', (tester) async {
      await open(tester, together);

      await tester.tap(find.byKey(const Key('space-info')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Shared with alex. Status and categories are shared; rating and '
          'playtime stay your own.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says that the space is empty', (tester) async {
      await open(tester, together, entries: const []);

      expect(find.text('Your shared space is empty'), findsOneWidget);
      expect(find.byKey(const Key('library-empty-add')), findsOneWidget);
    });

    testWidgets('the status bar counts the shared games', (tester) async {
      await open(tester, together);

      expect(find.text('2 shared games'), findsOneWidget);
    });

    testWidgets('refreshes the space every 30 seconds', (tester) async {
      final opened = await open(tester, waiting);
      expect(find.text('Cancel invitation'), findsOneWidget);

      opened.space.space = together;
      await tester.pump(spaceRefreshInterval);
      await tester.pumpAndSettle();

      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Cancel invitation'), findsNothing);
    });

    testWidgets('keeps the screen when a refresh fails', (tester) async {
      final opened = await open(tester, together);

      opened.space.getError = Exception('offline');
      await tester.pump(spaceRefreshInterval);
      await tester.pumpAndSettle();

      expect(find.text('Co-op backlog'), findsOneWidget);
    });
  });

  group('leaving', () {
    testWidgets('asks first and says what happens to the games', (
      tester,
    ) async {
      await open(tester, together);

      await tester.tap(find.byKey(const Key('space-leave')));
      await tester.pumpAndSettle();

      expect(find.text('Leave the shared space?'), findsOneWidget);
      expect(
        find.text(
          'You lose access to its entries. They stay with your partner; once '
          'nobody is left they are deleted.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Stay keeps the space', (tester) async {
      final opened = await open(tester, together);
      await tester.tap(find.byKey(const Key('space-leave')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();

      expect(opened.space.calls, isNot(contains('leave')));
      expect(find.text('Co-op backlog'), findsOneWidget);
    });

    testWidgets('Leave drops the space and its cached games', (tester) async {
      final opened = await open(tester, together);
      await tester.tap(find.byKey(const Key('space-leave')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('space-leave-confirm')));
      await tester.pumpAndSettle();

      expect(opened.space.calls, contains('leave'));
      expect(find.text('You left the shared space'), findsOneWidget);
      expect(find.text('Start a shared space'), findsOneWidget);
      expect(find.text('Portal 2'), findsNothing);
      await dismissToast(tester);
    });

    testWidgets('cancelling an invitation uses the same call', (tester) async {
      final opened = await open(tester, waiting);

      await tester.tap(find.byKey(const Key('space-leave')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('space-leave-confirm')));
      await tester.pumpAndSettle();

      expect(opened.space.calls, contains('leave'));
      await dismissToast(tester);
    });
  });

  group('the inspector in the space', () {
    testWidgets('does not offer Wrong game', (tester) async {
      await open(tester, together, location: '/space?entry=1');

      expect(find.byKey(const Key('inspector')), findsOneWidget);
      expect(find.byKey(const Key('inspector-wrong-game')), findsNothing);
      expect(find.byKey(const Key('inspector-change-cover')), findsOneWidget);
      expect(find.byKey(const Key('inspector-add-to-space')), findsNothing);
    });

    testWidgets('personal games can be added to the space', (tester) async {
      final opened = await open(
        tester,
        together,
        entries: [shared(1, 'Portal 2', steamAppId: 620)],
        location: '/library?entry=1',
      );
      final created = <String>[];
      opened.backlog.onCreate = (request, spaceId) async {
        created.add('${request.title} $spaceId ${request.steamAppId}');
      };

      await tester.tap(find.byKey(const Key('inspector-add-to-space')));
      await tester.pumpAndSettle();

      expect(created, ['Portal 2 4 620']);
      expect(
        find.text('Added "Portal 2" to your shared space'),
        findsOneWidget,
      );
      await dismissToast(tester);
    });

    testWidgets('games without Steam App ID cannot be shared', (tester) async {
      final opened = await open(
        tester,
        together,
        entries: [shared(1, 'Custom', steamAppId: null)],
        location: '/library?entry=1',
      );

      await tester.tap(find.byKey(const Key('inspector-add-to-space')));
      await tester.pumpAndSettle();

      expect(opened.backlog.created, isEmpty);
    });

    testWidgets('a game that is in the space links to it', (tester) async {
      final opened = await open(
        tester,
        together,
        entries: [
          const BacklogEntry(
            id: 1,
            title: 'Portal 2',
            steamAppId: 620,
            inSharedSpace: true,
          ),
        ],
        location: '/library?entry=1',
      );

      await tester.tap(find.byKey(const Key('inspector-in-space')));
      await tester.pumpAndSettle();

      expect(opened.location, startsWith(AppRoutes.space));
    });

    testWidgets('is not offered without an active space', (tester) async {
      await open(
        tester,
        noSpace,
        entries: [shared(1, 'Portal 2', steamAppId: 620)],
        location: '/library?entry=1',
      );

      expect(find.byKey(const Key('inspector-add-to-space')), findsNothing);
    });
  });

  group('adding games', () {
    testWidgets('+ Add Steam game targets the space', (tester) async {
      final opened = await open(tester, together);
      opened.games.onSearch = (term, deep) async => const [
        GameSearchResult(
          id: 7,
          title: 'Portal 2',
          genres: ['Puzzle'],
          platforms: ['PC'],
          mainStory: 9,
          mainStoryWithExtras: 12,
          completionist: 20,
          steamAppId: 620,
        ),
      ];

      await tester.tap(find.text('+ Add Steam game'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Portal');
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Portal 2').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-continue')));
      await tester.pumpAndSettle();

      expect(opened.location, contains('target=space'));
      expect(find.byKey(const Key('page-creation')), findsOneWidget);
      expect(find.text('Shared space'), findsWidgets);
    });
  });

  for (final themeId in ['shelfOled', 'light']) {
    testWidgets('golden: the shared space in $themeId', tags: 'golden', (
      tester,
    ) async {
      final opened = await open(
        tester,
        together,
        entries: [
          shared(1, 'It Takes Two', playtime: 12, partnerPlaytime: 14),
          shared(2, 'Overcooked! 2', playtime: 6, partnerPlaytime: 5),
          shared(3, 'A Way Out', playtime: 4, partnerPlaytime: 4),
          shared(4, 'Portal 2', playtime: 9, partnerPlaytime: 3),
        ],
      );
      opened.container.read(themeIdProvider.notifier).select(themeId);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/space_$themeId.png'),
      );
    });
  }

  testWidgets('golden: the invitation', tags: 'golden', (tester) async {
    await open(tester, invitation);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/space_invitation.png'),
    );
  });
}
