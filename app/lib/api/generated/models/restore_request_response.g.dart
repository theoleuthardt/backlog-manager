// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restore_request_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RestoreRequestResponse _$RestoreRequestResponseFromJson(
  Map<String, dynamic> json,
) => RestoreRequestResponse(
  id: (json['id'] as num).toInt(),
  backupId: (json['backup_id'] as num).toInt(),
  backupCreatedAt: DateTime.parse(json['backup_created_at'] as String),
  requestedBy: json['requested_by'] as String,
  requestedByMe: json['requested_by_me'] as bool,
  createdAt: DateTime.parse(json['created_at'] as String),
  expiresAt: DateTime.parse(json['expires_at'] as String),
  backupName: json['backup_name'] as String?,
);

Map<String, dynamic> _$RestoreRequestResponseToJson(
  RestoreRequestResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'backup_id': instance.backupId,
  'backup_created_at': instance.backupCreatedAt.toIso8601String(),
  'requested_by': instance.requestedBy,
  'requested_by_me': instance.requestedByMe,
  'created_at': instance.createdAt.toIso8601String(),
  'expires_at': instance.expiresAt.toIso8601String(),
  'backup_name': instance.backupName,
};
