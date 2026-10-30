import 'dart:async';

import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show backlog, pumpLibrary;
import '../space/space_page_test.dart' show FakeSpaceApi, together;

const hades = GameSearchResult(
  id: 1,
  title: 'Hades',
  imageUrl: 'https://img.example/h.jpg',
  genres: ['Roguelike', 'Action'],
  platforms: ['PC', 'Switch'],
  mainStory: 22,
  mainStoryWithExtras: 48,
  completionist: 95,
  description: 'Defy the god of the dead.',
  publisher: 'Supergiant Games',
  trailerUrl: 'https://www.youtube.com/watch?v=abcdefghijk',
);

class Tool {
  Tool(this.container, this.api, this.games);

  final ProviderContainer container;
  final FakeBacklogApi api;
  final FakeGamesApi games;

  String get location => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();
}

Future<Tool> openTool(
  WidgetTester tester, {
  String? location,
  bool settle = true,
  List<Override> overrides = const [],
  void Function(FakeBacklogApi api, FakeGamesApi games)? setUp,
}) async {
  final api = FakeBacklogApi(entries: backlog);
  final games = FakeGamesApi();
  setUp?.call(api, games);
  final container = await pumpLibrary(
    tester,
    api,
    height: 1100,
    overrides: [gamesApiProvider.overrideWithValue(games), ...overrides],
  );
  container.read(routerProvider).go(location ?? creationToolLocation(hades));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return Tool(container, api, games);
}

String textOf(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

Future<void> chooseStatus(WidgetTester tester, String status) async {
  await tester.ensureVisible(find.byKey(const Key('status-select')));
  await tester.tap(find.byKey(const Key('status-select')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(status).last);
  await tester.pumpAndSettle();
}

Future<void> choosePlatforms(WidgetTester tester, List<String> names) async {
  await tester.ensureVisible(find.byKey(const Key('creation-platform')));
  await tester.tap(find.byKey(const Key('creation-platform')));
  await tester.pumpAndSettle();
  for (final name in names) {
    final item = find.byKey(Key('creation-platform-$name'));
    await tester.ensureVisible(item);
    await tester.tap(item);
    await tester.pumpAndSettle();
  }
  await tester.tapAt(Offset.zero);
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('creation-submit')));
  await tester.pumpAndSettle();
}

void main() {
  group('from a search result', () {
    testWidgets('is filled with what the search found', (tester) async {
      await openTool(tester);

      expect(find.byKey(const Key('page-creation')), findsOneWidget);
      expect(textOf(tester, const Key('creation-title')), 'Hades');
      expect(textOf(tester, const Key('creation-genre')), 'Roguelike, Action');
      expect(textOf(tester, const Key('creation-main')), '22');
      expect(textOf(tester, const Key('creation-extra')), '48');
      expect(textOf(tester, const Key('creation-completionist')), '95');
      expect(
        textOf(tester, const Key('creation-publisher')),
        'Supergiant Games',
      );
      expect(find.text('Defy the god of the dead.'), findsOneWidget);
      expect(find.byKey(const Key('creation-warning')), findsNothing);
    });

    testWidgets('the title and the times are read-only', (tester) async {
      await openTool(tester);

      for (final key in [
        'creation-title',
        'creation-main',
        'creation-extra',
        'creation-completionist',
      ]) {
        expect(
          tester.widget<TextField>(find.byKey(Key(key))).enabled,
          isFalse,
          reason: key,
        );
      }
    });

    testWidgets('creates the entry with the chosen platform', (tester) async {
      final tool = await openTool(tester);

      await tester.tap(find.byKey(const Key('creation-platform')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('creation-platform-PC')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('creation-platform-Switch')));
      await tester.pumpAndSettle();
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await chooseStatus(tester, 'Not Started');
      await submit(tester);

      final request = tool.api.created.single;
      expect(request.title, 'Hades');
      expect(request.platform, ['Switch']);
      expect(request.genre, ['Roguelike', 'Action']);
      expect(request.status, 'Not Started');
      expect(request.interest, 5);
      expect(request.mainTime, '22.0');
      expect(request.description, 'Defy the god of the dead.');
      expect(request.imageLink, 'https://img.example/h.jpg');
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('the missing data warning', () {
    testWidgets('names what was not found and opens the times', (tester) async {
      await openTool(
        tester,
        location: Uri(
          path: '/creation-tool',
          queryParameters: {'title': 'Obscure', 'genres': 'Indie'},
        ).toString(),
      );

      expect(find.byKey(const Key('creation-warning')), findsOneWidget);
      expect(find.textContaining('No image found.'), findsOneWidget);
      expect(find.textContaining('No game beat times found.'), findsOneWidget);
      expect(find.text('Editable because no match was found.'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('creation-main')))
            .enabled,
        isTrue,
      );
    });
  });

  group('a custom game', () {
    String custom() => customGameLocation('My game');

    testWidgets('has an editable title, an image URL and editable times', (
      tester,
    ) async {
      await openTool(tester, location: custom());

      expect(find.text('New custom game'), findsOneWidget);
      expect(find.byKey(const Key('creation-warning')), findsNothing);
      expect(textOf(tester, const Key('creation-title')), 'My game');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('creation-title')))
            .enabled,
        isTrue,
      );
      expect(find.byKey(const Key('creation-image-url')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('creation-main')))
            .enabled,
        isTrue,
      );
    });

    testWidgets('creates the entry from what was typed', (tester) async {
      final tool = await openTool(tester, location: custom());

      await tester.enterText(find.byKey(const Key('creation-title')), 'Mine!');
      await tester.enterText(find.byKey(const Key('creation-genre')), 'Indie');
      await choosePlatforms(tester, ['PC']);
      await tester.enterText(
        find.byKey(const Key('creation-image-url')),
        'https://img.example/mine.jpg',
      );
      await tester.enterText(find.byKey(const Key('creation-main')), '7.5');
      await chooseStatus(tester, 'Not Started');
      await submit(tester);

      final request = tool.api.created.single;
      expect(request.title, 'Mine!');
      expect(request.genre, ['Indie']);
      expect(request.platform, ['PC']);
      expect(request.imageLink, 'https://img.example/mine.jpg');
      expect(request.mainTime, '7.5');
      expect(request.mainPlusExtraTime, isNull);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Change cover puts the chosen cover into the image URL', (
      tester,
    ) async {
      final tool = await openTool(
        tester,
        location: custom(),
        setUp: (api, games) {
          games.onGridSearch = (term) async => [
            const SteamGridDbMatch(id: 7, name: 'My game'),
          ];
          games.onCoversById = (id) async => ['https://cdn.example/c.png'];
        },
      );

      await tester.tap(find.byKey(const Key('creation-change-cover')));
      await tester.pumpAndSettle();
      expect(tool.games.calls, contains('grid-search My game'));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('cover-matches')),
          matching: find.bySemanticsLabel('My game'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Cover Option'));
      await tester.pumpAndSettle();

      expect(
        textOf(tester, const Key('creation-image-url')),
        'https://cdn.example/c.png',
      );
    });
  });

  group('validation', () {
    testWidgets('asks for a status first and creates nothing', (tester) async {
      final tool = await openTool(tester);

      await submit(tester);

      expect(find.text('Please select a status'), findsOneWidget);
      expect(tool.api.created, isEmpty);
      expect(tool.api.calls.where((c) => c.startsWith('duplicates')), isEmpty);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('asks for a genre', (tester) async {
      final tool = await openTool(tester);
      await chooseStatus(tester, 'Not Started');
      await tester.enterText(find.byKey(const Key('creation-genre')), '');

      await submit(tester);

      expect(find.text('Please enter at least one genre'), findsOneWidget);
      expect(tool.api.created, isEmpty);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('asks for a title of a custom game', (tester) async {
      final tool = await openTool(tester, location: customGameLocation(''));

      await submit(tester);

      expect(find.text('Please enter a title'), findsOneWidget);
      expect(tool.api.created, isEmpty);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('creating', () {
    testWidgets('shows "Created!" and goes back to the library', (
      tester,
    ) async {
      final tool = await openTool(tester);
      await chooseStatus(tester, 'Not Started');

      await submit(tester);

      expect(find.text('Created!'), findsOneWidget);
      expect(find.text('Entry created successfully!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(tool.location, AppRoutes.library);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a failure shows "Failed" and then the button again', (
      tester,
    ) async {
      final tool = await openTool(
        tester,
        setUp: (api, games) =>
            api.onCreate = (request, spaceId) async =>
                throw Exception('offline'),
      );
      await chooseStatus(tester, 'Not Started');

      await submit(tester);

      expect(find.text('Failed'), findsOneWidget);
      expect(find.textContaining('Failed to create'), findsOneWidget);
      expect(tool.location, startsWith('/creation-tool'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Add Game'), findsWidgets);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a retry that works is not reset by the old failure timer', (
      tester,
    ) async {
      var failing = true;
      final tool = await openTool(
        tester,
        setUp: (api, games) => api.onCreate = (request, spaceId) async {
          if (failing) throw Exception('offline');
        },
      );
      await chooseStatus(tester, 'Not Started');
      await submit(tester);
      expect(find.text('Failed'), findsOneWidget);

      failing = false;
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.tap(find.byKey(const Key('creation-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Created!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Created!'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('creation-submit')),
          matching: find.text('Add Game'),
        ),
        findsNothing,
      );
      expect(tool.api.created, hasLength(2));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Ctrl+Enter creates the entry', (tester) async {
      final tool = await openTool(tester);
      await chooseStatus(tester, 'Not Started');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(tool.api.created, hasLength(1));
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('duplicates', () {
    Tool? tool0;

    Future<void> openWithDuplicate(WidgetTester tester) async {
      tool0 = await openTool(
        tester,
        setUp: (api, games) =>
            api.onDuplicates = (title, steamAppId, spaceId) => const [
              BacklogEntry(
                id: 9,
                title: 'Hades',
                genre: ['Action'],
                platform: ['PC'],
                status: 'Completed',
                owned: true,
                playtime: 30,
              ),
            ],
      );
      await chooseStatus(tester, 'Not Started');
      await submit(tester);
    }

    testWidgets('asks before creating and shows what differs', (tester) async {
      await openWithDuplicate(tester);

      expect(find.text('Duplicate found'), findsOneWidget);
      expect(find.byKey(const Key('duplicate-9')), findsOneWidget);
      expect(find.text('- Action'), findsOneWidget);
      expect(find.text('+ Roguelike, Action'), findsOneWidget);
      expect(find.text('- Completed'), findsOneWidget);
      expect(find.text('+ Not Started'), findsOneWidget);
      expect(tool0!.api.created, isEmpty);
    });

    testWidgets('"Do not Add" creates nothing', (tester) async {
      await openWithDuplicate(tester);

      await tester.tap(find.text('Do not Add'));
      await tester.pumpAndSettle();

      expect(tool0!.api.created, isEmpty);
      expect(find.text('Duplicate found'), findsNothing);
      expect(find.text('Add Game'), findsWidgets);
    });

    testWidgets('"Add Anyway" creates the entry', (tester) async {
      await openWithDuplicate(tester);

      await tester.tap(find.byKey(const Key('duplicate-add-anyway')));
      await tester.pumpAndSettle();

      expect(tool0!.api.created, hasLength(1));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('asks for the title of the game, and its Steam App ID', (
      tester,
    ) async {
      final tool = await openTool(
        tester,
        setUp: (api, games) => games.onSteamAppId = (title) async => 1145360,
      );
      await chooseStatus(tester, 'Not Started');

      await submit(tester);

      expect(tool.api.calls, contains('duplicates Hades 1145360 personal'));
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('the Steam App ID', () {
    testWidgets('is looked up by the title and put into the field', (
      tester,
    ) async {
      final tool = await openTool(
        tester,
        setUp: (api, games) => games.onSteamAppId = (title) async => 1145360,
      );

      expect(tool.games.calls, contains('steam-app-id Hades'));
      expect(textOf(tester, const Key('creation-steam-app-id')), '1145360');
    });

    testWidgets('a custom game is not looked up', (tester) async {
      final tool = await openTool(tester, location: customGameLocation('Mine'));

      expect(
        tool.games.calls.where((c) => c.startsWith('steam-app-id')),
        isEmpty,
      );
    });

    testWidgets('prefills the playtime of the Steam account', (tester) async {
      final tool = await openTool(
        tester,
        setUp: (api, games) {
          games.onSteamAppId = (title) async => 1145360;
          api.onSteamPlaytime = (id) async => 18.5;
        },
      );

      expect(tool.api.calls, contains('steam-playtime 1145360'));
      expect(textOf(tester, const Key('creation-playtime')), '18.5');
    });

    testWidgets('keeps a playtime the user typed', (tester) async {
      final lookup = Completer<int?>();
      await openTool(
        tester,
        settle: false,
        setUp: (api, games) {
          games.onSteamAppId = (title) => lookup.future;
          api.onSteamPlaytime = (id) async => 18.5;
        },
      );
      await tester.enterText(find.byKey(const Key('creation-playtime')), '3');
      lookup.complete(1145360);
      await tester.pumpAndSettle();

      expect(textOf(tester, const Key('creation-playtime')), '3');
    });

    testWidgets('the submit button waits while the lookup runs', (
      tester,
    ) async {
      final lookup = Completer<int?>();
      await openTool(
        tester,
        settle: false,
        setUp: (api, games) => games.onSteamAppId = (title) => lookup.future,
      );

      expect(find.byKey(const Key('creation-lookup-loading')), findsOneWidget);
      final waiting = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byKey(const Key('creation-submit')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(waiting.opacity, lessThan(1));

      lookup.complete(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('creation-lookup-loading')), findsNothing);
    });

    testWidgets('the submit button waits for the playtime of a typed App ID', (
      tester,
    ) async {
      final playtime = Completer<double?>();
      await openTool(
        tester,
        setUp: (api, games) =>
            api.onSteamPlaytime = (steamAppId) => playtime.future,
      );

      await tester.enterText(
        find.byKey(const Key('creation-steam-app-id')),
        '620',
      );
      await tester.pump();

      expect(
        tester
            .widget<ShelfButton>(find.byKey(const Key('creation-submit')))
            .onPressed,
        isNull,
      );
      playtime.complete(12);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ShelfButton>(find.byKey(const Key('creation-submit')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('can be typed in when none was found', (tester) async {
      final tool = await openTool(tester);
      await chooseStatus(tester, 'Not Started');

      await tester.enterText(
        find.byKey(const Key('creation-steam-app-id')),
        '620',
      );
      await submit(tester);

      expect(tool.api.created.single.steamAppId, 620);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('the About text', () {
    final long = GameSearchResult(
      id: 2,
      title: 'Long',
      imageUrl: 'https://img.example/l.jpg',
      genres: ['Action'],
      platforms: ['PC'],
      mainStory: 1,
      mainStoryWithExtras: 1,
      completionist: 1,
      description:
          'A very long description that goes on and on about the game. '
          'It keeps going so that it needs far more than four lines in the '
          'narrow side column of the creation tool. '
          '${'More and more words follow here. ' * 30}',
    );

    testWidgets('has a fixed height and folds out on request', (tester) async {
      await openTool(tester, location: creationToolLocation(long));
      final about = find.byKey(const Key('creation-about'));
      final folded = tester.getSize(about).height;

      expect(find.byKey(const Key('creation-about-toggle')), findsOneWidget);
      expect(find.text('Show more'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('creation-about-toggle')),
      );
      await tester.tap(find.byKey(const Key('creation-about-toggle')));
      await tester.pumpAndSettle();

      expect(tester.getSize(about).height, greaterThan(folded));
      expect(tester.getSize(about).height, lessThanOrEqualTo(260));
      expect(find.text('Show less'), findsOneWidget);

      await tester.tap(find.byKey(const Key('creation-about-toggle')));
      await tester.pumpAndSettle();

      expect(tester.getSize(about).height, folded);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the toggle works from the keyboard', (tester) async {
      await openTool(tester, location: creationToolLocation(long));
      await tester.ensureVisible(
        find.byKey(const Key('creation-about-toggle')),
      );

      Focus.of(tester.element(find.text('Show more'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('a short text has no toggle', (tester) async {
      await openTool(tester);

      expect(find.byKey(const Key('creation-about')), findsOneWidget);
      expect(find.byKey(const Key('creation-about-toggle')), findsNothing);
    });
  });

  group('the platform', () {
    testWidgets('PC (Microsoft Windows) is preselected when offered', (
      tester,
    ) async {
      const multi = GameSearchResult(
        id: 3,
        title: 'Multi',
        imageUrl: '',
        genres: ['Action'],
        platforms: ['PlayStation 5', 'PC (Microsoft Windows)', 'Switch'],
        mainStory: 1,
        mainStoryWithExtras: 1,
        completionist: 1,
      );
      await openTool(tester, location: creationToolLocation(multi));

      expect(
        find.descendant(
          of: find.byKey(const Key('creation-platform')),
          matching: find.text('PC (Microsoft Windows)'),
        ),
        findsOneWidget,
      );
    });
  });

  group('review and notes', () {
    testWidgets('explain on hover why they are disabled', (tester) async {
      await openTool(tester);

      expect(
        find.byTooltip('Stars and review need the status Completed'),
        findsWidgets,
      );

      await chooseStatus(tester, 'Completed');

      expect(
        find.byTooltip('Stars and review need the status Completed'),
        findsNothing,
      );
    });

    testWidgets('need the status Completed', (tester) async {
      await openTool(tester);

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('creation-review')))
            .enabled,
        isFalse,
      );
      await chooseStatus(tester, 'Completed');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('creation-review')))
            .enabled,
        isTrue,
      );
    });

    testWidgets('are sent with the entry', (tester) async {
      final tool = await openTool(tester);
      await chooseStatus(tester, 'Completed');
      await tester.enterText(find.byKey(const Key('creation-review')), 'Great');
      await tester.enterText(find.byKey(const Key('creation-note')), 'Replay');

      await submit(tester);

      final request = tool.api.created.single;
      expect(request.review, 'Great');
      expect(request.note, 'Replay');
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('leaving', () {
    testWidgets('Search again goes back and opens the search', (tester) async {
      final tool = await openTool(tester);

      await tester.tap(find.byKey(const Key('creation-search-again')));
      await tester.pumpAndSettle();

      expect(tool.location, AppRoutes.library);
      expect(find.text('Search for a game'), findsOneWidget);
    });

    testWidgets('Cancel goes back to the library', (tester) async {
      final tool = await openTool(tester);

      await tester.tap(find.byKey(const Key('creation-cancel')));
      await tester.pumpAndSettle();

      expect(tool.location, AppRoutes.library);
    });
  });

  group('everything the inspector can set (#544)', () {
    testWidgets('takes several platforms from the drop-down', (tester) async {
      final tool = await openTool(tester);

      await choosePlatforms(tester, ['Switch', 'PS5']);
      await chooseStatus(tester, 'Not Started');
      await submit(tester);

      expect(tool.api.created.single.platform, ['PC', 'Switch', 'PS5']);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('takes a platform of its own', (tester) async {
      final tool = await openTool(tester);

      await tester.ensureVisible(find.byKey(const Key('creation-platform')));
      await tester.tap(find.byKey(const Key('creation-platform')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('creation-platform-other')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('platform-new')),
        'Retroid Pocket 6',
      );
      await tester.tap(find.byKey(const Key('platform-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('platforms-done')));
      await tester.pumpAndSettle();
      await chooseStatus(tester, 'Not Started');
      await submit(tester);

      expect(tool.api.created.single.platform, ['PC', 'Retroid Pocket 6']);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('sends the publisher as edited', (tester) async {
      final tool = await openTool(tester);

      expect(
        textOf(tester, const Key('creation-publisher')),
        'Supergiant Games',
      );
      await tester.enterText(
        find.byKey(const Key('creation-publisher')),
        'Supergiant',
      );
      await chooseStatus(tester, 'Not Started');
      await submit(tester);

      expect(tool.api.created.single.publisher, 'Supergiant');
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('adds the chosen categories to the new game', (tester) async {
      final tool = await openTool(
        tester,
        setUp: (api, games) => api.categoryList = const [
          Category(id: 7, name: 'Cozy', color: '#22c55e'),
          Category(id: 8, name: 'Co-op', color: '#3b82f6'),
        ],
      );

      await tester.ensureVisible(find.byKey(const Key('creation-categories')));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('creation-categories')),
          matching: find.byKey(const Key('category-add')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category-option-Cozy')));
      await tester.pumpAndSettle();
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await chooseStatus(tester, 'Not Started');
      await submit(tester);

      final id = tool.api.stored.values.last.id;
      expect(tool.api.calls, contains('add-category $id 7 personal'));
      expect(
        tool.api.calls.where((call) => call.startsWith('add-category')),
        hasLength(1),
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('adds the mods to the new game', (tester) async {
      final tool = await openTool(tester);

      await tester.ensureVisible(find.byKey(const Key('mod-add')));
      await tester.tap(find.byKey(const Key('mod-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('mod-name')), 'Hell Mode+');
      await tester.enterText(
        find.byKey(const Key('mod-url')),
        'https://mods.example/hell',
      );
      await tester.tap(find.byKey(const Key('mod-save')));
      await tester.pumpAndSettle();
      expect(find.text('Hell Mode+'), findsOneWidget);
      await chooseStatus(tester, 'Not Started');
      await submit(tester);

      final id = tool.api.stored.values.last.id;
      expect(
        tool.api.calls,
        contains('add-mod $id Hell Mode+ https://mods.example/hell'),
      );
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('the batch mode (#548)', () {
    GameSearchResult result(int id, String title) => GameSearchResult(
      id: id,
      title: title,
      imageUrl: 'https://img.example/$id.jpg',
      genres: const ['Action'],
      platforms: const ['PC'],
      mainStory: 10,
      mainStoryWithExtras: 20,
      completionist: 30,
    );

    Future<Tool> openBatch(
      WidgetTester tester, {
      List<String> titles = const ['Hades', 'Celeste', 'Mystery Game'],
      List<Override> overrides = const [],
      void Function(FakeBacklogApi api, FakeGamesApi games)? setUp,
    }) => openTool(
      tester,
      location: batchCreationLocation(titles),
      overrides: overrides,
      setUp: (api, games) {
        games.onSearch = (term, deep) async => switch (term) {
          'Hades' => [result(1, 'Hades'), result(9, 'Hades II')],
          'Celeste' => [result(2, 'Celeste')],
          _ => const [],
        };
        setUp?.call(api, games);
      },
    );

    Future<void> chooseDefaultStatus(WidgetTester tester, String status) async {
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('batch-status')),
          matching: find.byKey(const Key('status-select')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('status-option-$status')).last);
      await tester.pumpAndSettle();
    }

    testWidgets('lists every title with its best search result', (
      tester,
    ) async {
      await openBatch(tester);

      expect(find.text('New Games'), findsOneWidget);
      expect(find.text('Add 3 Games'), findsOneWidget);
      for (final index in [0, 1, 2]) {
        expect(find.byKey(Key('batch-item-$index')), findsOneWidget);
      }
      expect(find.text('Hades'), findsOneWidget);
      expect(find.text('Hades II'), findsNothing);
      expect(find.text('No match found - a custom game'), findsOneWidget);
      expect(
        find.byKey(const Key('creation-title')),
        findsNothing,
        reason: 'the games are folded in',
      );
    });

    testWidgets('folds out the normal form of a game', (tester) async {
      await openBatch(tester);

      await tester.tap(find.byKey(const Key('batch-toggle-1')));
      await tester.pumpAndSettle();

      expect(textOf(tester, const Key('creation-title')), 'Celeste');
      expect(textOf(tester, const Key('creation-main')), '10');
    });

    testWidgets('creates every game with the status for all', (tester) async {
      final tool = await openBatch(tester);

      await chooseDefaultStatus(tester, 'Not Started');
      await tester.tap(find.byKey(const Key('batch-toggle-2')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('creation-genre')), 'Indie');
      await choosePlatforms(tester, ['PC']);
      await submit(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        [for (final r in tool.api.created) r.title],
        ['Hades', 'Celeste', 'Mystery Game'],
      );
      expect([
        for (final r in tool.api.created) r.status,
      ], everyElement('Not Started'));
      expect(tool.location, AppRoutes.library);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a game can change the status for itself', (tester) async {
      final tool = await openBatch(tester, titles: ['Hades', 'Celeste']);

      await chooseDefaultStatus(tester, 'Not Started');
      await tester.tap(find.byKey(const Key('batch-toggle-0')));
      await tester.pumpAndSettle();
      final ownStatus = find.descendant(
        of: find.byKey(const Key('batch-item-0')),
        matching: find.byKey(const Key('status-select')),
      );
      await tester.ensureVisible(ownStatus);
      await tester.tap(ownStatus);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('status-option-Completed')).last);
      await tester.pumpAndSettle();
      await submit(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        {for (final r in tool.api.created) r.title: r.status},
        {'Hades': 'Completed', 'Celeste': 'Not Started'},
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('opens and names a game that is not complete', (tester) async {
      final tool = await openBatch(tester);

      await chooseDefaultStatus(tester, 'Not Started');
      await submit(tester);

      expect(tool.api.created, isEmpty);
      expect(find.textContaining('Mystery Game:'), findsOneWidget);
      expect(find.byKey(const Key('creation-genre')), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Remove takes a game off the list', (tester) async {
      final tool = await openBatch(tester, titles: ['Hades', 'Celeste']);

      await tester.tap(find.byKey(const Key('batch-remove-0')));
      await tester.pumpAndSettle();
      expect(find.text('Add 1 Game'), findsOneWidget);
      await chooseDefaultStatus(tester, 'Not Started');
      await submit(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect([for (final r in tool.api.created) r.title], ['Celeste']);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Wrong Game? replaces the match of a game', (tester) async {
      await openBatch(tester, titles: ['Hades']);

      await tester.tap(find.byKey(const Key('batch-wrong-0')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hades II').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this game'));
      await tester.pumpAndSettle();

      expect(find.text('Hades II'), findsOneWidget);
    });

    testWidgets('a declined duplicate keeps the page busy until the rest is '
        'created', (tester) async {
      final tool = await openBatch(
        tester,
        titles: ['Hades', 'Celeste'],
        setUp: (api, games) =>
            api.onDuplicates = (title, steamAppId, spaceId) =>
                title == 'Hades' ? [backlog.first] : const [],
      );

      await chooseDefaultStatus(tester, 'Not Started');
      await tester.tap(find.byKey(const Key('creation-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Do not Add'), findsOneWidget);
      expect(
        tester
            .widget<ShelfButton>(find.byKey(const Key('creation-submit')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Do not Add'));
      await tester.pumpAndSettle();

      expect([for (final r in tool.api.created) r.title], ['Celeste']);
      expect(find.byKey(const Key('batch-item-0')), findsOneWidget);
      expect(find.byKey(const Key('batch-item-1')), findsNothing);
      expect(find.text('Add 1 Game'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a game that fails stays in the list', (tester) async {
      final tool = await openBatch(
        tester,
        titles: ['Hades', 'Celeste'],
        setUp: (api, games) => api.onCreate = (request, spaceId) async {
          if (request.title == 'Celeste') throw Exception('offline');
        },
      );

      await chooseDefaultStatus(tester, 'Not Started');
      await submit(tester);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(Uri.parse(tool.location).path, AppRoutes.creationTool);
      expect(find.byKey(const Key('batch-item-0')), findsOneWidget);
      expect(find.byKey(const Key('batch-item-1')), findsNothing);
      expect(find.text('Celeste'), findsOneWidget);
      expect(find.text('Add 1 Game'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('adds every game to both backlogs', (tester) async {
      final createdIn = <(String, int?)>[];
      await openBatch(
        tester,
        titles: ['Hades', 'Celeste'],
        overrides: [spaceApiProvider.overrideWithValue(FakeSpaceApi(together))],
        setUp: (api, games) =>
            api.onCreate = (request, spaceId) async =>
                createdIn.add((request.title, spaceId)),
      );

      await tester.tap(find.byKey(const Key('batch-target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Both').last);
      await tester.pumpAndSettle();
      await chooseDefaultStatus(tester, 'Not Started');
      await submit(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(createdIn, [
        ('Hades', null),
        ('Hades', 4),
        ('Celeste', null),
        ('Celeste', 4),
      ]);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('adding to the Shared Space', () {
    List<Override> withSpace() => [
      spaceApiProvider.overrideWithValue(FakeSpaceApi(together)),
    ];

    testWidgets('offers no target without an active space', (tester) async {
      await openTool(tester);

      expect(find.byKey(const Key('creation-target')), findsNothing);
    });

    testWidgets('adds to my backlog by default', (tester) async {
      await openTool(tester, overrides: withSpace());

      expect(
        find.descendant(
          of: find.byKey(const Key('creation-target')),
          matching: find.text('My Backlog'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('target=space in the address preselects the space', (
      tester,
    ) async {
      await openTool(
        tester,
        overrides: withSpace(),
        location: creationToolLocation(hades, inSpace: true),
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('creation-target')),
          matching: find.text('Shared Space'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a game without Steam App ID can go to the space', (
      tester,
    ) async {
      final createdIn = <int?>[];
      final tool = await openTool(
        tester,
        overrides: withSpace(),
        location: creationToolLocation(hades, inSpace: true),
        setUp: (api, games) {
          api.onCreate = (request, spaceId) async => createdIn.add(spaceId);
        },
      );

      await chooseStatus(tester, 'In Progress');
      await submit(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(createdIn, [4]);
      expect(tool.location, AppRoutes.space);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('checks duplicates in the space and creates there', (
      tester,
    ) async {
      final duplicateScopes = <int?>[];
      final createdIn = <int?>[];
      final tool = await openTool(
        tester,
        overrides: withSpace(),
        location: creationToolLocation(hades, inSpace: true),
        setUp: (api, games) {
          games.onSteamAppId = (title) async => 1145360;
          api
            ..onDuplicates = (title, steamAppId, spaceId) {
              duplicateScopes.add(spaceId);
              return const [];
            }
            ..onCreate = (request, spaceId) async => createdIn.add(spaceId);
        },
      );

      await chooseStatus(tester, 'In Progress');
      await submit(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(duplicateScopes, [4]);
      expect(createdIn, [4]);
      expect(tool.location, AppRoutes.space);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('adds to both, my backlog and the space', (tester) async {
      final duplicateScopes = <int?>[];
      final createdIn = <int?>[];
      final tool = await openTool(
        tester,
        overrides: withSpace(),
        setUp: (api, games) {
          api
            ..onDuplicates = (title, steamAppId, spaceId) {
              duplicateScopes.add(spaceId);
              return const [];
            }
            ..onCreate = (request, spaceId) async => createdIn.add(spaceId);
        },
      );

      await tester.tap(find.byKey(const Key('creation-target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Both').last);
      await tester.pumpAndSettle();
      await chooseStatus(tester, 'In Progress');
      await submit(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(duplicateScopes, unorderedEquals([null, 4]));
      expect(createdIn, [null, 4]);
      expect(tool.api.created, hasLength(2));
      expect(tool.location, AppRoutes.library);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('picks categories for each target of both', (tester) async {
      await openTool(tester, overrides: withSpace());

      await tester.tap(find.byKey(const Key('creation-target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Both').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('creation-categories')), findsOneWidget);
      expect(
        find.byKey(const Key('creation-categories-space')),
        findsOneWidget,
      );
    });

    testWidgets('switching the target back creates in my backlog', (
      tester,
    ) async {
      final createdIn = <int?>[];
      final tool = await openTool(
        tester,
        overrides: withSpace(),
        location: creationToolLocation(hades, inSpace: true),
        setUp: (api, games) {
          games.onSteamAppId = (title) async => 1145360;
          api.onCreate = (request, spaceId) async => createdIn.add(spaceId);
        },
      );

      await tester.tap(find.byKey(const Key('creation-target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Backlog').last);
      await tester.pumpAndSettle();
      await chooseStatus(tester, 'In Progress');
      await submit(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(createdIn, [null]);
      expect(tool.location, AppRoutes.library);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  for (final themeId in ['shelfOled', 'light']) {
    testWidgets('golden: the creation tool in $themeId', tags: 'golden', (
      tester,
    ) async {
      final tool = await openTool(
        tester,
        setUp: (api, games) => games.onSteamAppId = (title) async => 1145360,
      );
      tool.container.read(themeIdProvider.notifier).select(themeId);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/creation_tool_$themeId.png'),
      );
    });
  }
}
