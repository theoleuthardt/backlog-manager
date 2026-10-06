// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'achievement_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AchievementInfo _$AchievementInfoFromJson(Map<String, dynamic> json) =>
    AchievementInfo(
      apiname: json['apiname'] as String,
      displayName: json['display_name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      achieved: json['achieved'] as bool,
      unlockTime: (json['unlock_time'] as num).toInt(),
      hidden: json['hidden'] as bool,
    );

Map<String, dynamic> _$AchievementInfoToJson(AchievementInfo instance) =>
    <String, dynamic>{
      'apiname': instance.apiname,
      'display_name': instance.displayName,
      'description': instance.description,
      'icon': instance.icon,
      'achieved': instance.achieved,
      'unlock_time': instance.unlockTime,
      'hidden': instance.hidden,
    };
