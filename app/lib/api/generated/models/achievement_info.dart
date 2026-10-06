// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'achievement_info.g.dart';

@JsonSerializable()
class AchievementInfo {
  const AchievementInfo({
    required this.apiname,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.achieved,
    required this.unlockTime,
    required this.hidden,
  });

  factory AchievementInfo.fromJson(Map<String, Object?> json) =>
      _$AchievementInfoFromJson(json);

  final String apiname;
  @JsonKey(name: 'display_name')
  final String displayName;
  final String? description;
  final String? icon;
  final bool achieved;
  @JsonKey(name: 'unlock_time')
  final int unlockTime;
  final bool hidden;

  Map<String, Object?> toJson() => _$AchievementInfoToJson(this);
}
