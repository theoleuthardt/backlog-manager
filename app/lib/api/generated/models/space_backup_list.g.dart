// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_backup_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpaceBackupList _$SpaceBackupListFromJson(Map<String, dynamic> json) =>
    SpaceBackupList(
      backups: (json['backups'] as List<dynamic>)
          .map((e) => SpaceBackupSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      restoreRequest: json['restore_request'] == null
          ? null
          : RestoreRequestResponse.fromJson(
              json['restore_request'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$SpaceBackupListToJson(SpaceBackupList instance) =>
    <String, dynamic>{
      'backups': instance.backups,
      'restore_request': instance.restoreRequest,
    };
