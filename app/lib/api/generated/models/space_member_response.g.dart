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
    );

Map<String, dynamic> _$SpaceMemberResponseToJson(
  SpaceMemberResponse instance,
) => <String, dynamic>{
  'username': instance.username,
  'status': instance.status,
  'is_me': instance.isMe,
};
