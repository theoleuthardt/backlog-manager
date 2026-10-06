// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'igdb_genre.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IgdbGenre _$IgdbGenreFromJson(Map<String, dynamic> json) => IgdbGenre(
  id: (json['id'] as num).toInt(),
  checksum: json['checksum'] as String?,
  createdAt: (json['created_at'] as num?)?.toInt(),
  name: json['name'] as String?,
  slug: json['slug'] as String?,
  updatedAt: (json['updated_at'] as num?)?.toInt(),
  url: json['url'] as String?,
);

Map<String, dynamic> _$IgdbGenreToJson(IgdbGenre instance) => <String, dynamic>{
  'id': instance.id,
  'checksum': instance.checksum,
  'created_at': instance.createdAt,
  'name': instance.name,
  'slug': instance.slug,
  'updated_at': instance.updatedAt,
  'url': instance.url,
};
