import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/domain/filter_tokens.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

BacklogEntry game(
  int id, {
  String status = 'Not Started',
  List<String> genre = const [],
  List<String> platform = const [],
  double? playtime,
}) {
  return BacklogEntry(
    id: id,
    title: 'Game $id',
    status: status,
    genre: genre,
    platform: platform,
    playtime: playtime,
  );
}

void main() {
  late FakeBacklogApi api;
  late ProviderContainer container;

  setUp(() {
    api =
        FakeBacklogApi(
            entries: [
              game(
                1,
                genre: ['RPG', 'Action'],
                platform: ['PC'],
                playtime: 12.2,
              ),
              game(
                2,
                status: 'Replaying',
                genre: ['Puzzle'],
                platform: ['Switch'],
              ),
              game(
                3,
                genre: ['rpg'],
                platform: ['PC', 'Switch'],
                playtime: 61.4,
              ),
            ],
          )
          ..categoryList = const [
            Category(id: 1, name: 'Story', color: '#38bdf8'),
            Category(id: 2, name: 'co-op', color: '#4ade80'),
          ]
          ..statusList = const [CustomStatus(id: 1, name: 'Replaying')];
    container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [backlogApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
  });

  FiltersNotifier notifier() => container.read(filtersProvider.notifier);
  Future<void> load() async {
    await container.read(entriesProvider(null).future);
    await container.read(categoriesProvider(null).future);
    await container.read(customStatusesProvider(null).future);
  }

  group('the filters', () {
    test('start empty', () {
      expect(container.read(filtersProvider).search, '');
      expect(container.read(activeFilterCountProvider), 0);
    });

    test('hold the search, owned only, lists and ranges', () async {
      await load();
      notifier()
        ..setSearch('zelda')
        ..setOwnedOnly(true)
        ..setList(FilterField.genre, ['RPG'])
        ..setRange(FilterField.playtime, (5, 20));

      final filters = container.read(filtersProvider);
      expect(filters.search, 'zelda');
      expect(filters.ownedOnly, isTrue);
      expect(filters.genres, ['RPG']);
      expect(filters.playtime, (5, 20));
    });

    test('treat a range over the whole slider as no filter', () async {
      await load();
      final bound = container.read(filterBoundsProvider).playtime;

      notifier().setRange(FilterField.playtime, (0, bound));

      expect(container.read(filtersProvider).playtime, isNull);
    });

    test(
      'count each list, range and owned only once, not the search',
      () async {
        await load();
        notifier()
          ..setSearch('zelda')
          ..setOwnedOnly(true)
          ..setList(FilterField.platform, ['PC', 'Switch'])
          ..setRange(FilterField.interest, (2, 9));

        expect(container.read(activeFilterCountProvider), 3);
      },
    );

    test('clear one filter and reset all but the search', () async {
      await load();
      notifier()
        ..setSearch('zelda')
        ..setList(FilterField.genre, ['RPG'])
        ..setList(FilterField.status, ['Completed']);

      notifier().clear(FilterField.genre);
      expect(container.read(filtersProvider).genres, isEmpty);
      expect(container.read(filtersProvider).statuses, ['Completed']);

      notifier().reset();
      expect(container.read(filtersProvider).statuses, isEmpty);
      expect(container.read(filtersProvider).search, 'zelda');
    });

    test('survive until the session changes', () async {
      await load();
      notifier().setList(FilterField.genre, ['RPG']);
      expect(container.read(filtersProvider).genres, ['RPG']);

      container.read(sessionGenerationProvider.notifier).bump();

      expect(container.read(filtersProvider).genres, isEmpty);
    });

    test('drop selected categories that no longer exist', () async {
      await load();
      notifier().setList(FilterField.category, ['Story', 'Deleted']);

      final filters = container.read(effectiveFiltersProvider);

      expect(filters.categories, ['Story']);
      expect(container.read(activeFilterCountProvider), 1);
    });
  });

  group('the options', () {
    test('list the platforms and genres of the entries once, sorted', () async {
      await load();

      final options = container.read(filterOptionsProvider);

      expect(options.platforms, ['PC', 'Switch']);
      expect(options.genres, ['Action', 'Puzzle', 'rpg', 'RPG']);
    });

    test(
      'list the built-in, custom and entry statuses in that order',
      () async {
        api.stored[4] = game(4, status: 'Imported');
        await load();

        expect(container.read(filterOptionsProvider).statuses, [
          'Not Started',
          'In Progress',
          'Completed',
          'On Hold',
          'Dropped',
          'Replaying',
          'Imported',
        ]);
      },
    );

    test('list the category names alphabetically', () async {
      await load();

      expect(container.read(filterOptionsProvider).categories, [
        'co-op',
        'Story',
      ]);
    });
  });

  group('the bounds', () {
    test('come from the largest values of the entries', () async {
      await load();

      final bounds = container.read(filterBoundsProvider);

      expect(bounds.playtime, 62);
      expect(bounds.mainTime, 10);
      expect(bounds.interest, 10);
    });
  });
}
