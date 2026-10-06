// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'igdb_cover.g.dart';

@JsonSerializable()
class IgdbCover {
  const IgdbCover({
    required this.id,
    this.alphaChannel,
    this.animated,
    this.checksum,
    this.game,
    this.gameLocalization,
    this.height,
    this.imageId,
    this.url,
    this.width,
  });

  factory IgdbCover.fromJson(Map<String, Object?> json) =>
      _$IgdbCoverFromJson(json);

  final int id;
  @JsonKey(name: 'alpha_channel')
  final bool? alphaChannel;
  final bool? animated;
  final String? checksum;
  final int? game;
  @JsonKey(name: 'game_localization')
  final int? gameLocalization;
  final int? height;
  @JsonKey(name: 'image_id')
  final String? imageId;
  final String? url;
  final int? width;

  Map<String, Object?> toJson() => _$IgdbCoverToJson(this);
}
