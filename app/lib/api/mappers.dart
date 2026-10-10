import 'package:backlog_manager/api/generated/export.dart';
import 'package:backlog_manager/domain/achievements.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/price_listings.dart' as price;
import 'package:backlog_manager/domain/wishlist_sync_report.dart';

/// Parses the backend's decimal strings (playtime, HowLongToBeat times);
/// anything that is not a finite number is treated as missing.
double? toNumber(String? value) {
  if (value == null) return null;
  final parsed = double.tryParse(value);
  return parsed != null && parsed.isFinite ? parsed : null;
}

BacklogEntry entryFromResponse(BacklogEntryResponse entry) {
  return BacklogEntry(
    id: entry.id,
    title: entry.title,
    imageLink: entry.imageLink ?? '',
    imageAlt: entry.title,
    genre: entry.genre,
    platform: entry.platform,
    status: entry.status,
    owned: entry.owned,
    interest: entry.interest,
    reviewStars: entry.reviewStars,
    review: entry.review,
    note: entry.note,
    description: entry.description,
    trailerLink: entry.trailerLink,
    mainTime: toNumber(entry.mainTime),
    mainPlusExtraTime: toNumber(entry.mainPlusExtraTime),
    completionTime: toNumber(entry.completionTime),
    playtime: toNumber(entry.playtime),
    partnerPlaytime: toNumber(entry.partnerPlaytime),
    inSharedSpace: entry.inSharedSpace,
    steamAppId: entry.steamAppId,
    completedAt: entry.completedAt,
  );
}

Category categoryFromResponse(CategoryResponse category) {
  return Category(
    id: category.id,
    name: category.name,
    color: category.color,
    description: category.description,
  );
}

CustomStatus customStatusFromResponse(CustomStatusResponse status) {
  return CustomStatus(id: status.id, name: status.name);
}

Space spaceFromResponse(SpaceResponse space) {
  return Space(
    spaceId: space.spaceId,
    myStatus: space.myStatus,
    members: [
      for (final member in space.members)
        SpaceMember(
          username: member.username,
          status: member.status,
          isMe: member.isMe,
        ),
    ],
  );
}

WishlistSyncReport wishlistSyncReportFromResponse(
  SteamWishlistSyncReport report,
) {
  WishlistChange change(SteamWishlistChange change) => WishlistChange(
    steamAppId: change.steamAppId,
    title: change.title,
    imageLink: change.imageLink,
  );
  return WishlistSyncReport(
    since: report.since,
    updatedAt: report.updatedAt,
    added: (report.added ?? const []).map(change).toList(),
    removed: (report.removed ?? const []).map(change).toList(),
  );
}

price.PriceInfo priceInfoFromResponse(GamePrice response) {
  return price.PriceInfo(
    deals: [
      for (final deal in response.deals)
        price.PriceDeal(
          store: deal.store,
          iconUrl: deal.icon,
          price: deal.price.toDouble(),
          retailPrice: deal.retailPrice.toDouble(),
          url: deal.url,
        ),
    ],
    onSale: response.onSale,
    cheapestPriceEver: toNumber(response.cheapestPriceEver),
  );
}

price.KeyShopOffer keyShopOfferFromResponse(KeyShopOffer offer) {
  return price.KeyShopOffer(
    shop: offer.shop,
    title: offer.title,
    price: offer.price.toDouble(),
    currency: offer.currency,
    url: offer.url,
    discountPct: offer.discountPct,
  );
}

GameAchievements achievementsFromResponse(AchievementProgress progress) {
  return GameAchievements(
    unlocked: progress.unlocked,
    total: progress.total,
    items: [
      for (final item in progress.achievements)
        GameAchievement(
          apiname: item.apiname,
          displayName: item.displayName,
          description: item.description,
          icon: item.icon,
          achieved: item.achieved,
          hidden: item.hidden,
        ),
    ],
  );
}

GameSearchResult gameSearchResultFromResponse(EnrichedResult result) {
  final appId = result.steamAppId;
  return GameSearchResult(
    id: result.id,
    title: result.title,
    imageUrl: result.imageUrl,
    steamAppId: appId is num ? appId.toInt() : int.tryParse('$appId'),
    genres: result.genres,
    platforms: result.platforms,
    mainStory: result.mainStory.toDouble(),
    mainStoryWithExtras: result.mainStoryWithExtras.toDouble(),
    completionist: result.completionist.toDouble(),
    description: result.description,
    publisher: result.publisher,
    trailerUrl: result.trailerUrl,
  );
}

SteamGridDbMatch steamGridDbMatchFromResponse(SteamGridDbSearchResult match) {
  return SteamGridDbMatch(id: match.id, name: match.name);
}
