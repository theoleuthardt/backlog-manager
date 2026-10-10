import 'dart:async';

import 'package:backlog_manager/api/mappers.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/domain/achievements.dart';
import 'package:backlog_manager/domain/price_listings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long a price answer is kept before the server is asked again.
final priceCacheTtlProvider = Provider<Duration>(
  (ref) => const Duration(hours: 1),
);

/// How long the achievements of a game are kept.
final achievementsCacheTtlProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 5),
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
  final price = await ref.watch(gamesApiProvider).price(steamAppId);
  _cacheFor(ref, ref.read(priceCacheTtlProvider));
  return price;
});

/// The key shop offers for a title, cached for an hour.
final keyShopPricesProvider = FutureProvider.autoDispose
    .family<List<KeyShopOffer>, String>((ref, title) async {
      final offers = await ref.watch(gamesApiProvider).keyShopPrices(title);
      _cacheFor(ref, ref.read(priceCacheTtlProvider));
      return offers;
    });

/// The achievements of the signed-in account for a Steam game, cached for a
/// few minutes.
final achievementsProvider = FutureProvider.autoDispose
    .family<GameAchievements, int>((ref, steamAppId) async {
      ref.watch(sessionGenerationProvider);
      final progress = await ref
          .watch(backlogApiProvider)
          .achievements(steamAppId);
      _cacheFor(ref, ref.read(achievementsCacheTtlProvider));
      return achievementsFromResponse(progress);
    });
