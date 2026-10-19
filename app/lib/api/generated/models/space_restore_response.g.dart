// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_restore_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpaceRestoreResponse _$SpaceRestoreResponseFromJson(
  Map<String, dynamic> json,
) => SpaceRestoreResponse(
  restored: json['restored'] as bool,
  request: json['request'] == null
      ? null
      : RestoreRequestResponse.fromJson(
          json['request'] as Map<String, dynamic>,
        ),
  result: json['result'] == null
      ? null
      : RestoreResult.fromJson(json['result'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SpaceRestoreResponseToJson(
  SpaceRestoreResponse instance,
) => <String, dynamic>{
  'restored': instance.restored,
  'request': instance.request,
  'result': instance.result,
};
