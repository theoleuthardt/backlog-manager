// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enriched_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EnrichedResult _$EnrichedResultFromJson(Map<String, dynamic> json) =>
    EnrichedResult(
      id: (json['id'] as num).toInt(),
      hltbId: (json['hltb_id'] as num).toInt(),
      title: json['title'] as String,
      imageUrl: json['image_url'] as String?,
      genres: (json['genres'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      platforms: (json['platforms'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      mainStory: json['main_story'] as num,
      mainStoryWithExtras: json['main_story_with_extras'] as num,
      completionist: json['completionist'] as num,
      steamAppId: json['steam_app_id'],
      description: json['description'] as String?,
      publisher: json['publisher'] as String?,
      trailerUrl: json['trailer_url'] as String?,
    );

Map<String, dynamic> _$EnrichedResultToJson(EnrichedResult instance) =>
    <String, dynamic>{
      'id': instance.id,
      'hltb_id': instance.hltbId,
      'title': instance.title,
      'image_url': instance.imageUrl,
      'genres': instance.genres,
      'platforms': instance.platforms,
      'main_story': instance.mainStory,
      'main_story_with_extras': instance.mainStoryWithExtras,
      'completionist': instance.completionist,
      'steam_app_id': instance.steamAppId,
      'description': instance.description,
      'publisher': instance.publisher,
      'trailer_url': instance.trailerUrl,
    };
