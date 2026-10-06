// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'igdb_search_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IgdbSearchResult _$IgdbSearchResultFromJson(Map<String, dynamic> json) =>
    IgdbSearchResult(
      id: (json['id'] as num).toInt(),
      alternativeName: json['alternative_name'] as String?,
      game: (json['game'] as num?)?.toInt(),
      name: json['name'] as String?,
      publishedAt: (json['published_at'] as num?)?.toInt(),
    );

Map<String, dynamic> _$IgdbSearchResultToJson(IgdbSearchResult instance) =>
    <String, dynamic>{
      'id': instance.id,
      'alternative_name': instance.alternativeName,
      'game': instance.game,
      'name': instance.name,
      'published_at': instance.publishedAt,
    };
