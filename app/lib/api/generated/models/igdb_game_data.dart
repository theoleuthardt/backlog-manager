// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'igdb_game_data.g.dart';

@JsonSerializable()
class IgdbGameData {
  const IgdbGameData({
    required this.id,
    this.gameModes,
    this.aggregatedRating,
    this.aggregatedRatingCount,
    this.alternativeNames,
    this.artworks,
    this.bundles,
    this.cover,
    this.createdAt,
    this.dlcs,
    this.expansions,
    this.externalGames,
    this.firstReleaseDate,
    this.franchises,
    this.gameEngines,
    this.ageRatings,
    this.genres,
    this.hypes,
    this.involvedCompanies,
    this.keywords,
    this.name,
    this.platforms,
    this.playerPerspectives,
    this.rating,
    this.ratingCount,
    this.releaseDates,
    this.screenshots,
    this.similarGames,
    this.slug,
    this.parentGame,
    this.summary,
    this.tags,
    this.themes,
    this.totalRating,
    this.totalRatingCount,
    this.updatedAt,
    this.url,
    this.videos,
    this.websites,
    this.checksum,
    this.languageSupports,
    this.gameLocalizations,
    this.collections,
    this.gameType,
    this.storyline,
  });

  factory IgdbGameData.fromJson(Map<String, Object?> json) =>
      _$IgdbGameDataFromJson(json);

  final int id;
  @JsonKey(name: 'age_ratings')
  final List<int>? ageRatings;
  @JsonKey(name: 'aggregated_rating')
  final num? aggregatedRating;
  @JsonKey(name: 'aggregated_rating_count')
  final int? aggregatedRatingCount;
  @JsonKey(name: 'alternative_names')
  final List<int>? alternativeNames;
  final List<int>? artworks;
  final List<int>? bundles;
  final int? cover;
  @JsonKey(name: 'created_at')
  final int? createdAt;
  final List<int>? dlcs;
  final List<int>? expansions;
  @JsonKey(name: 'external_games')
  final List<int>? externalGames;
  @JsonKey(name: 'first_release_date')
  final int? firstReleaseDate;
  final List<int>? franchises;
  @JsonKey(name: 'game_engines')
  final List<int>? gameEngines;
  @JsonKey(name: 'game_modes')
  final List<int>? gameModes;
  final List<int>? genres;
  final int? hypes;
  @JsonKey(name: 'involved_companies')
  final List<int>? involvedCompanies;
  final List<int>? keywords;
  final String? name;
  final List<int>? platforms;
  @JsonKey(name: 'player_perspectives')
  final List<int>? playerPerspectives;
  final num? rating;
  @JsonKey(name: 'rating_count')
  final int? ratingCount;
  @JsonKey(name: 'release_dates')
  final List<int>? releaseDates;
  final List<int>? screenshots;
  @JsonKey(name: 'similar_games')
  final List<int>? similarGames;
  final String? slug;
  final String? storyline;
  final String? summary;
  final List<int>? tags;
  final List<int>? themes;
  @JsonKey(name: 'total_rating')
  final num? totalRating;
  @JsonKey(name: 'total_rating_count')
  final int? totalRatingCount;
  @JsonKey(name: 'updated_at')
  final int? updatedAt;
  final String? url;
  final List<int>? videos;
  final List<int>? websites;
  final String? checksum;
  @JsonKey(name: 'language_supports')
  final List<int>? languageSupports;
  @JsonKey(name: 'game_localizations')
  final List<int>? gameLocalizations;
  final List<int>? collections;
  @JsonKey(name: 'game_type')
  final int? gameType;
  @JsonKey(name: 'parent_game')
  final int? parentGame;

  Map<String, Object?> toJson() => _$IgdbGameDataToJson(this);
}
