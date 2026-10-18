// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_entry_mod_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateEntryModRequest _$CreateEntryModRequestFromJson(
  Map<String, dynamic> json,
) => CreateEntryModRequest(
  name: json['name'] as String,
  url: json['url'] as String?,
);

Map<String, dynamic> _$CreateEntryModRequestToJson(
  CreateEntryModRequest instance,
) => <String, dynamic>{'name': instance.name, 'url': instance.url};
