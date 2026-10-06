// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpaceResponse _$SpaceResponseFromJson(Map<String, dynamic> json) =>
    SpaceResponse(
      spaceId: (json['space_id'] as num?)?.toInt(),
      myStatus: json['my_status'] as String?,
      members: (json['members'] as List<dynamic>)
          .map((e) => SpaceMemberResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SpaceResponseToJson(SpaceResponse instance) =>
    <String, dynamic>{
      'space_id': instance.spaceId,
      'my_status': instance.myStatus,
      'members': instance.members,
    };
