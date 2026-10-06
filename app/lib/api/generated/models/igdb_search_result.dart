// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'igdb_search_result.g.dart';

@JsonSerializable()
class IgdbSearchResult {
  const IgdbSearchResult({
    required this.id,
    this.alternativeName,
    this.game,
    this.name,
    this.publishedAt,
  });

  factory IgdbSearchResult.fromJson(Map<String, Object?> json) =>
      _$IgdbSearchResultFromJson(json);

  final int id;
  @JsonKey(name: 'alternative_name')
  final String? alternativeName;
  final int? game;
  final String? name;
  @JsonKey(name: 'published_at')
  final int? publishedAt;

  Map<String, Object?> toJson() => _$IgdbSearchResultToJson(this);
}
