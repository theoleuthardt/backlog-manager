// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'steam_wishlist_item.g.dart';

@JsonSerializable()
class SteamWishlistItem {
  const SteamWishlistItem({
    required this.appid,
    this.priority = 0,
    this.dateAdded = 0,
  });

  factory SteamWishlistItem.fromJson(Map<String, Object?> json) =>
      _$SteamWishlistItemFromJson(json);

  final int appid;
  final int priority;
  @JsonKey(name: 'date_added')
  final int dateAdded;

  Map<String, Object?> toJson() => _$SteamWishlistItemToJson(this);
}
