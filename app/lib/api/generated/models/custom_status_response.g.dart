// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_status_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CustomStatusResponse _$CustomStatusResponseFromJson(
  Map<String, dynamic> json,
) => CustomStatusResponse(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
);

Map<String, dynamic> _$CustomStatusResponseToJson(
  CustomStatusResponse instance,
) => <String, dynamic>{'id': instance.id, 'name': instance.name};
