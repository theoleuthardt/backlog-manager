// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_mod_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EntryModResponse _$EntryModResponseFromJson(Map<String, dynamic> json) =>
    EntryModResponse(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      url: json['url'] as String?,
    );

Map<String, dynamic> _$EntryModResponseToJson(EntryModResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'url': instance.url,
    };
