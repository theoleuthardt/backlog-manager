// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'enriched_result.g.dart';

@JsonSerializable()
class EnrichedResult {
  const EnrichedResult({
    required this.id,
    required this.hltbId,
    required this.title,
    required this.imageUrl,
    required this.genres,
    required this.platforms,
    required this.mainStory,
    required this.mainStoryWithExtras,
    required this.completionist,
    this.steamAppId,
    this.description,
    this.publisher,
    this.trailerUrl,
  });

  factory EnrichedResult.fromJson(Map<String, Object?> json) =>
      _$EnrichedResultFromJson(json);

  final int id;
  @JsonKey(name: 'hltb_id')
  final int hltbId;
  final String title;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  final List<String> genres;
  final List<String> platforms;
  @JsonKey(name: 'main_story')
  final num mainStory;
  @JsonKey(name: 'main_story_with_extras')
  final num mainStoryWithExtras;
  final num completionist;
  @JsonKey(name: 'steam_app_id')
  final dynamic steamAppId;
  final String? description;
  final String? publisher;
  @JsonKey(name: 'trailer_url')
  final String? trailerUrl;

  Map<String, Object?> toJson() => _$EnrichedResultToJson(this);
}
