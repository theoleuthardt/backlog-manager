// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'igdb_platform.g.dart';

@JsonSerializable()
class IgdbPlatform {
  const IgdbPlatform({
    required this.id,
    this.abbreviation,
    this.alternativeName,
    this.category,
    this.checksum,
    this.createdAt,
    this.generation,
    this.name,
    this.platformFamily,
    this.platformLogo,
    this.platformType,
    this.slug,
    this.summary,
    this.updatedAt,
    this.url,
    this.versions,
    this.websites,
  });

  factory IgdbPlatform.fromJson(Map<String, Object?> json) =>
      _$IgdbPlatformFromJson(json);

  final int id;
  final String? abbreviation;
  @JsonKey(name: 'alternative_name')
  final String? alternativeName;
  final int? category;
  final String? checksum;
  @JsonKey(name: 'created_at')
  final int? createdAt;
  final int? generation;
  final String? name;
  @JsonKey(name: 'platform_family')
  final int? platformFamily;
  @JsonKey(name: 'platform_logo')
  final int? platformLogo;
  @JsonKey(name: 'platform_type')
  final int? platformType;
  final String? slug;
  final String? summary;
  @JsonKey(name: 'updated_at')
  final int? updatedAt;
  final String? url;
  final List<int>? versions;
  final List<int>? websites;

  Map<String, Object?> toJson() => _$IgdbPlatformToJson(this);
}
