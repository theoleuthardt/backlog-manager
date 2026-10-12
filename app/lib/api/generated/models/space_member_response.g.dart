// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_member_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpaceMemberResponse _$SpaceMemberResponseFromJson(Map<String, dynamic> json) =>
    SpaceMemberResponse(
      username: json['username'] as String,
      status: json['status'] as String,
      isMe: json['is_me'] as bool,
      avatarUpdatedAt: json['avatar_updated_at'] == null
          ? null
          : DateTime.parse(json['avatar_updated_at'] as String),
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$SpaceMemberResponseToJson(
  SpaceMemberResponse instance,
) => <String, dynamic>{
  'username': instance.username,
  'status': instance.status,
  'is_me': instance.isMe,
  'user_id': instance.userId,
  'avatar_updated_at': instance.avatarUpdatedAt?.toIso8601String(),
};
