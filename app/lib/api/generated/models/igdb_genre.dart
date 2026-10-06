// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'igdb_genre.g.dart';

@JsonSerializable()
class IgdbGenre {
  const IgdbGenre({
    required this.id,
    this.checksum,
    this.createdAt,
    this.name,
    this.slug,
    this.updatedAt,
    this.url,
  });

  factory IgdbGenre.fromJson(Map<String, Object?> json) =>
      _$IgdbGenreFromJson(json);

  final int id;
  final String? checksum;
  @JsonKey(name: 'created_at')
  final int? createdAt;
  final String? name;
  final String? slug;
  @JsonKey(name: 'updated_at')
  final int? updatedAt;
  final String? url;

  Map<String, Object?> toJson() => _$IgdbGenreToJson(this);
}
