// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'backlog_entry_response.g.dart';

@JsonSerializable()
class BacklogEntryResponse {
  const BacklogEntryResponse({
    required this.id,
    required this.title,
    required this.genre,
    required this.platform,
    required this.status,
    required this.owned,
    required this.interest,
    required this.createdAt,
    required this.updatedAt,
    this.inSharedSpace = false,
    this.releaseDate,
    this.imageLink,
    this.description,
    this.trailerLink,
    this.mainTime,
    this.mainPlusExtraTime,
    this.completionTime,
    this.playtime,
    this.partnerPlaytime,
    this.steamAppId,
    this.reviewStars,
    this.review,
    this.note,
    this.completedAt,
  });

  factory BacklogEntryResponse.fromJson(Map<String, Object?> json) =>
      _$BacklogEntryResponseFromJson(json);

  final int id;
  final String title;
  final List<String> genre;
  final List<String> platform;
  final String status;
  final bool owned;
  final int interest;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @JsonKey(name: 'release_date')
  final DateTime? releaseDate;
  @JsonKey(name: 'image_link')
  final String? imageLink;
  final String? description;
  @JsonKey(name: 'trailer_link')
  final String? trailerLink;
  @JsonKey(name: 'main_time')
  final String? mainTime;
  @JsonKey(name: 'main_plus_extra_time')
  final String? mainPlusExtraTime;
  @JsonKey(name: 'completion_time')
  final String? completionTime;
  final String? playtime;
  @JsonKey(name: 'partner_playtime')
  final String? partnerPlaytime;
  @JsonKey(name: 'in_shared_space')
  final bool inSharedSpace;
  @JsonKey(name: 'steam_app_id')
  final int? steamAppId;
  @JsonKey(name: 'review_stars')
  final int? reviewStars;
  final String? review;
  final String? note;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;

  Map<String, Object?> toJson() => _$BacklogEntryResponseToJson(this);
}
