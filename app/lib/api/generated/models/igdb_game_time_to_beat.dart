// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'igdb_game_time_to_beat.g.dart';

@JsonSerializable()
class IgdbGameTimeToBeat {
  const IgdbGameTimeToBeat({
    required this.id,
    this.checksum,
    this.completely,
    this.count,
    this.createdAt,
    this.gameId,
    this.hastily,
    this.normally,
    this.updatedAt,
  });

  factory IgdbGameTimeToBeat.fromJson(Map<String, Object?> json) =>
      _$IgdbGameTimeToBeatFromJson(json);

  final int id;
  final String? checksum;
  final int? completely;
  final int? count;
  @JsonKey(name: 'created_at')
  final int? createdAt;
  @JsonKey(name: 'game_id')
  final int? gameId;
  final int? hastily;
  final int? normally;
  @JsonKey(name: 'updated_at')
  final int? updatedAt;

  Map<String, Object?> toJson() => _$IgdbGameTimeToBeatToJson(this);
}
