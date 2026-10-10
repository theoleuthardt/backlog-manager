// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'steam_wishlist_change.dart';

part 'steam_wishlist_sync_report.g.dart';

@JsonSerializable()
class SteamWishlistSyncReport {
  const SteamWishlistSyncReport({
    this.since,
    this.updatedAt,
    this.added,
    this.removed,
  });

  factory SteamWishlistSyncReport.fromJson(Map<String, Object?> json) =>
      _$SteamWishlistSyncReportFromJson(json);

  final DateTime? since;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  final List<SteamWishlistChange>? added;
  final List<SteamWishlistChange>? removed;

  Map<String, Object?> toJson() => _$SteamWishlistSyncReportToJson(this);
}
