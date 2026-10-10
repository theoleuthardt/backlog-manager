import 'package:backlog_manager/api/generated/export.dart';
import 'package:backlog_manager/domain/models.dart';
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
    added: (report.added ?? const []).map(change).toList(),
    removed: (report.removed ?? const []).map(change).toList(),
  );
}
