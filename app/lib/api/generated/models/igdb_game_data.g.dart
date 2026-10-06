// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'igdb_game_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IgdbGameData _$IgdbGameDataFromJson(Map<String, dynamic> json) => IgdbGameData(
  id: (json['id'] as num).toInt(),
  gameModes: (json['game_modes'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  aggregatedRating: json['aggregated_rating'] as num?,
  aggregatedRatingCount: (json['aggregated_rating_count'] as num?)?.toInt(),
  alternativeNames: (json['alternative_names'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  artworks: (json['artworks'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  bundles: (json['bundles'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  cover: (json['cover'] as num?)?.toInt(),
  createdAt: (json['created_at'] as num?)?.toInt(),
  dlcs: (json['dlcs'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  expansions: (json['expansions'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  externalGames: (json['external_games'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  firstReleaseDate: (json['first_release_date'] as num?)?.toInt(),
  franchises: (json['franchises'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  gameEngines: (json['game_engines'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  ageRatings: (json['age_ratings'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  genres: (json['genres'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  hypes: (json['hypes'] as num?)?.toInt(),
  involvedCompanies: (json['involved_companies'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  keywords: (json['keywords'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  name: json['name'] as String?,
  platforms: (json['platforms'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  playerPerspectives: (json['player_perspectives'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  rating: json['rating'] as num?,
  ratingCount: (json['rating_count'] as num?)?.toInt(),
  releaseDates: (json['release_dates'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  screenshots: (json['screenshots'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  similarGames: (json['similar_games'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  slug: json['slug'] as String?,
  parentGame: (json['parent_game'] as num?)?.toInt(),
  summary: json['summary'] as String?,
  tags: (json['tags'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  themes: (json['themes'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  totalRating: json['total_rating'] as num?,
  totalRatingCount: (json['total_rating_count'] as num?)?.toInt(),
  updatedAt: (json['updated_at'] as num?)?.toInt(),
  url: json['url'] as String?,
  videos: (json['videos'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  websites: (json['websites'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  checksum: json['checksum'] as String?,
  languageSupports: (json['language_supports'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  gameLocalizations: (json['game_localizations'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  collections: (json['collections'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  gameType: (json['game_type'] as num?)?.toInt(),
  storyline: json['storyline'] as String?,
);

Map<String, dynamic> _$IgdbGameDataToJson(IgdbGameData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'age_ratings': instance.ageRatings,
      'aggregated_rating': instance.aggregatedRating,
      'aggregated_rating_count': instance.aggregatedRatingCount,
      'alternative_names': instance.alternativeNames,
      'artworks': instance.artworks,
      'bundles': instance.bundles,
      'cover': instance.cover,
      'created_at': instance.createdAt,
      'dlcs': instance.dlcs,
      'expansions': instance.expansions,
      'external_games': instance.externalGames,
      'first_release_date': instance.firstReleaseDate,
      'franchises': instance.franchises,
      'game_engines': instance.gameEngines,
      'game_modes': instance.gameModes,
      'genres': instance.genres,
      'hypes': instance.hypes,
      'involved_companies': instance.involvedCompanies,
      'keywords': instance.keywords,
      'name': instance.name,
      'platforms': instance.platforms,
      'player_perspectives': instance.playerPerspectives,
      'rating': instance.rating,
      'rating_count': instance.ratingCount,
      'release_dates': instance.releaseDates,
      'screenshots': instance.screenshots,
      'similar_games': instance.similarGames,
      'slug': instance.slug,
      'storyline': instance.storyline,
      'summary': instance.summary,
      'tags': instance.tags,
      'themes': instance.themes,
      'total_rating': instance.totalRating,
      'total_rating_count': instance.totalRatingCount,
      'updated_at': instance.updatedAt,
      'url': instance.url,
      'videos': instance.videos,
      'websites': instance.websites,
      'checksum': instance.checksum,
      'language_supports': instance.languageSupports,
      'game_localizations': instance.gameLocalizations,
      'collections': instance.collections,
      'game_type': instance.gameType,
      'parent_game': instance.parentGame,
    };
