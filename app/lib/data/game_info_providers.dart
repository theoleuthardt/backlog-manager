import 'dart:async';

import 'package:backlog_manager/api/mappers.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/domain/achievements.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/domain/price_listings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long a price answer is kept before the server is asked again.
final priceCacheTtlProvider = Provider<Duration>(
  (ref) => const Duration(hours: 1),
);

/// How long the Steam playtime of a game is kept.
final playtimeCacheTtlProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 10),
);

/// How long the achievements of a game are kept.
final achievementsCacheTtlProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 5),
);

/// How long the results of a game search are kept.
final searchCacheTtlProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 5),
);

/// How long covers and Steam App IDs are kept.
final lookupCacheTtlProvider = Provider<Duration>(
  (ref) => const Duration(hours: 1),
);

/// Keeps an auto-dispose provider alive for [ttl] after its last listener
/// went away, so opening the same sheet again does not ask the server again.
void _cacheFor(Ref ref, Duration ttl) {
  final link = ref.keepAlive();
  final timer = Timer(ttl, link.close);
  ref.onDispose(timer.cancel);
}

/// The CheapShark prices of a Steam game, cached for an hour.
final gamePriceProvider = FutureProvider.autoDispose.family<PriceInfo, int>((
  ref,
  steamAppId,
) async {
  final api = ref.watch(gamesApiProvider);
  final ttl = ref.read(priceCacheTtlProvider);
  final price = await api.price(steamAppId);
  if (ref.mounted) _cacheFor(ref, ttl);
  return price;
});

/// The key shop offers for a title, cached for an hour.
final keyShopPricesProvider = FutureProvider.autoDispose
    .family<List<KeyShopOffer>, String>((ref, title) async {
      final api = ref.watch(gamesApiProvider);
      final ttl = ref.read(priceCacheTtlProvider);
      final offers = await api.keyShopPrices(title);
      if (ref.mounted) _cacheFor(ref, ttl);
      return offers;
    });

/// The achievements of the signed-in account for a Steam game, cached for a
/// few minutes.
final achievementsProvider = FutureProvider.autoDispose
    .family<GameAchievements, int>((ref, steamAppId) async {
      ref.watch(sessionGenerationProvider);
      final api = ref.watch(backlogApiProvider);
      final ttl = ref.read(achievementsCacheTtlProvider);
      final progress = await api.achievements(steamAppId);
      if (ref.mounted) _cacheFor(ref, ttl);
      return achievementsFromResponse(progress);
    });

/// What a game search asks for.
typedef GameSearchQuery = ({String term, bool deep});

/// The games for a search term, cached for five minutes. An empty term asks
/// nothing.
final gameSearchProvider = FutureProvider.autoDispose
    .family<List<GameSearchResult>, GameSearchQuery>((ref, query) async {
      if (query.term.trim().isEmpty) return const [];
      final api = ref.watch(gamesApiProvider);
      final ttl = ref.read(searchCacheTtlProvider);
      final results = await api.search(query.term.trim(), deep: query.deep);
      if (ref.mounted) _cacheFor(ref, ttl);
      return results;
    });

/// The Steam App ID of the game with a title, cached for an hour.
final steamAppIdProvider = FutureProvider.autoDispose.family<int?, String>((
  ref,
  title,
) async {
  final api = ref.watch(gamesApiProvider);
  final ttl = ref.read(lookupCacheTtlProvider);
  final appId = await api.steamAppId(title);
  if (ref.mounted) _cacheFor(ref, ttl);
  return appId;
});

/// The SteamGridDB covers of a Steam App ID, cached for an hour.
final steamGridDbCoversProvider = FutureProvider.autoDispose
    .family<List<String>, int>((ref, steamAppId) async {
      final api = ref.watch(gamesApiProvider);
      final ttl = ref.read(lookupCacheTtlProvider);
      final covers = await api.steamGridDbCovers(steamAppId);
      if (ref.mounted) _cacheFor(ref, ttl);
      return covers;
    });

/// The games SteamGridDB finds for a term, cached for five minutes.
final steamGridDbSearchProvider = FutureProvider.autoDispose
    .family<List<SteamGridDbMatch>, String>((ref, term) async {
      if (term.trim().isEmpty) return const [];
      final api = ref.watch(gamesApiProvider);
      final ttl = ref.read(searchCacheTtlProvider);
      final matches = await api.steamGridDbSearch(term.trim());
      if (ref.mounted) _cacheFor(ref, ttl);
      return matches;
    });

/// The covers of a game found on SteamGridDB, cached for an hour.
final steamGridDbCoversByIdProvider = FutureProvider.autoDispose
    .family<List<String>, int>((ref, gameId) async {
      final api = ref.watch(gamesApiProvider);
      final ttl = ref.read(lookupCacheTtlProvider);
      final covers = await api.steamGridDbCoversById(gameId);
      if (ref.mounted) _cacheFor(ref, ttl);
      return covers;
    });

/// The hours the Steam account has played of a game, cached for ten minutes.
final steamPlaytimeProvider = FutureProvider.autoDispose.family<double?, int>((
  ref,
  steamAppId,
) async {
  ref.watch(sessionGenerationProvider);
  final api = ref.watch(backlogApiProvider);
  final ttl = ref.read(playtimeCacheTtlProvider);
  final hours = await api.steamPlaytime(steamAppId);
  if (ref.mounted) _cacheFor(ref, ttl);
  return hours;
});
