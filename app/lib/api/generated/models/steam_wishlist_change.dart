// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'steam_wishlist_change.g.dart';

@JsonSerializable()
class SteamWishlistChange {
  const SteamWishlistChange({
    required this.steamAppId,
    required this.title,
    this.imageLink,
  });

  factory SteamWishlistChange.fromJson(Map<String, Object?> json) =>
      _$SteamWishlistChangeFromJson(json);

  @JsonKey(name: 'steam_app_id')
  final int steamAppId;
  final String title;
  @JsonKey(name: 'image_link')
  final String? imageLink;

  Map<String, Object?> toJson() => _$SteamWishlistChangeToJson(this);
}
