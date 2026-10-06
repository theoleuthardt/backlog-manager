// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'steam_grid_db_search_result.g.dart';

@JsonSerializable()
class SteamGridDbSearchResult {
  const SteamGridDbSearchResult({required this.id, required this.name});

  factory SteamGridDbSearchResult.fromJson(Map<String, Object?> json) =>
      _$SteamGridDbSearchResultFromJson(json);

  final int id;
  final String name;

  Map<String, Object?> toJson() => _$SteamGridDbSearchResultToJson(this);
}
