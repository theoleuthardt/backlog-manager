import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/game_info_providers.dart';
import 'package:backlog_manager/data/games_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

ProviderContainer container(
  FakeGamesApi games,
  FakeBacklogApi backlog, {
  Duration ttl = const Duration(hours: 1),
}) {
  final result = ProviderContainer(
    overrides: [
      gamesApiProvider.overrideWithValue(games),
      backlogApiProvider.overrideWithValue(backlog),
      priceCacheTtlProvider.overrideWithValue(ttl),
      achievementsCacheTtlProvider.overrideWithValue(ttl),
      searchCacheTtlProvider.overrideWithValue(ttl),
      lookupCacheTtlProvider.overrideWithValue(ttl),
    ],
  );
  addTearDown(result.dispose);
  return result;
}

void main() {
  test('a price is asked for once while it is cached', () async {
    final games = FakeGamesApi();
    final c = container(games, FakeBacklogApi());

    final first = c.listen(gamePriceProvider(1), (_, _) {});
    await c.read(gamePriceProvider(1).future);
    first.close();
    final second = c.listen(gamePriceProvider(1), (_, _) {});
    await c.read(gamePriceProvider(1).future);
    second.close();

    expect(games.calls, ['price 1']);
  });

  test('a price is asked for again once the cache ran out', () async {
    final games = FakeGamesApi();
    final c = container(games, FakeBacklogApi(), ttl: Duration.zero);

    final first = c.listen(gamePriceProvider(1), (_, _) {});
    await c.read(gamePriceProvider(1).future);
    first.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final second = c.listen(gamePriceProvider(1), (_, _) {});
    await c.read(gamePriceProvider(1).future);
    second.close();

    expect(games.calls, ['price 1', 'price 1']);
  });

  test('key shop offers are cached per title', () async {
    final games = FakeGamesApi();
    final c = container(games, FakeBacklogApi());

    for (final title in ['Hades', 'Hades', 'Celeste']) {
      final sub = c.listen(keyShopPricesProvider(title), (_, _) {});
      await c.read(keyShopPricesProvider(title).future);
      sub.close();
    }

    expect(games.calls, ['keys Hades', 'keys Celeste']);
  });

  test('achievements come from the backlog api, mapped', () async {
    final backlog = FakeBacklogApi();
    final c = container(FakeGamesApi(), backlog);

    final achievements = await c.read(achievementsProvider(620).future);

    expect(achievements.unlocked, 3);
    expect(achievements.total, 15);
    expect(backlog.calls, contains('achievements 620'));
  });

  test(
    'a search is asked for once per term and depth while it is cached',
    () async {
      final games = FakeGamesApi();
      final c = container(games, FakeBacklogApi());

      for (final query in [
        (term: 'hades', deep: false),
        (term: 'hades', deep: false),
        (term: 'hades', deep: true),
      ]) {
        final sub = c.listen(gameSearchProvider(query), (_, _) {});
        await c.read(gameSearchProvider(query).future);
        sub.close();
      }

      expect(games.calls, ['search hades', 'search hades deep']);
    },
  );

  test('an empty search asks nothing', () async {
    final games = FakeGamesApi();
    final c = container(games, FakeBacklogApi());

    final results = await c.read(
      gameSearchProvider((term: '  ', deep: false)).future,
    );

    expect(results, isEmpty);
    expect(games.calls, isEmpty);
  });

  test('the covers and the Steam App ID of a game are cached', () async {
    final games = FakeGamesApi();
    final c = container(games, FakeBacklogApi());

    for (var i = 0; i < 2; i++) {
      final covers = c.listen(steamGridDbCoversProvider(620), (_, _) {});
      await c.read(steamGridDbCoversProvider(620).future);
      covers.close();
      final id = c.listen(steamAppIdProvider('Portal 2'), (_, _) {});
      await c.read(steamAppIdProvider('Portal 2').future);
      id.close();
    }

    expect(games.calls, ['covers 620', 'steam-app-id Portal 2']);
  });
}
