// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'steam_wishlist_sync_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SteamWishlistSyncReport _$SteamWishlistSyncReportFromJson(
  Map<String, dynamic> json,
) => SteamWishlistSyncReport(
  since: json['since'] == null ? null : DateTime.parse(json['since'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  added: (json['added'] as List<dynamic>?)
      ?.map((e) => SteamWishlistChange.fromJson(e as Map<String, dynamic>))
      .toList(),
  removed: (json['removed'] as List<dynamic>?)
      ?.map((e) => SteamWishlistChange.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SteamWishlistSyncReportToJson(
  SteamWishlistSyncReport instance,
) => <String, dynamic>{
  'since': instance.since?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
  'added': instance.added,
  'removed': instance.removed,
};
