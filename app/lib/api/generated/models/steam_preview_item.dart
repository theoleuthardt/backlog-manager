// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'steam_preview_item.g.dart';

@JsonSerializable()
class SteamPreviewItem {
  const SteamPreviewItem({
    required this.steamAppId,
    required this.title,
    this.imageLink,
    this.playtime,
  });

  factory SteamPreviewItem.fromJson(Map<String, Object?> json) =>
      _$SteamPreviewItemFromJson(json);

  @JsonKey(name: 'steam_app_id')
  final int steamAppId;
  final String title;
  @JsonKey(name: 'image_link')
  final String? imageLink;
  final String? playtime;

  Map<String, Object?> toJson() => _$SteamPreviewItemToJson(this);
}
