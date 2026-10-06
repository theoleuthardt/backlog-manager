// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'igdb_platform.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IgdbPlatform _$IgdbPlatformFromJson(Map<String, dynamic> json) => IgdbPlatform(
  id: (json['id'] as num).toInt(),
  abbreviation: json['abbreviation'] as String?,
  alternativeName: json['alternative_name'] as String?,
  category: (json['category'] as num?)?.toInt(),
  checksum: json['checksum'] as String?,
  createdAt: (json['created_at'] as num?)?.toInt(),
  generation: (json['generation'] as num?)?.toInt(),
  name: json['name'] as String?,
  platformFamily: (json['platform_family'] as num?)?.toInt(),
  platformLogo: (json['platform_logo'] as num?)?.toInt(),
  platformType: (json['platform_type'] as num?)?.toInt(),
  slug: json['slug'] as String?,
  summary: json['summary'] as String?,
  updatedAt: (json['updated_at'] as num?)?.toInt(),
  url: json['url'] as String?,
  versions: (json['versions'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  websites: (json['websites'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
);

Map<String, dynamic> _$IgdbPlatformToJson(IgdbPlatform instance) =>
    <String, dynamic>{
      'id': instance.id,
      'abbreviation': instance.abbreviation,
      'alternative_name': instance.alternativeName,
      'category': instance.category,
      'checksum': instance.checksum,
      'created_at': instance.createdAt,
      'generation': instance.generation,
      'name': instance.name,
      'platform_family': instance.platformFamily,
      'platform_logo': instance.platformLogo,
      'platform_type': instance.platformType,
      'slug': instance.slug,
      'summary': instance.summary,
      'updated_at': instance.updatedAt,
      'url': instance.url,
      'versions': instance.versions,
      'websites': instance.websites,
    };
