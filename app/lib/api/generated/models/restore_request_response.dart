// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'restore_request_response.g.dart';

@JsonSerializable()
class RestoreRequestResponse {
  const RestoreRequestResponse({
    required this.id,
    required this.backupId,
    required this.backupCreatedAt,
    required this.requestedBy,
    required this.requestedByMe,
    required this.createdAt,
    required this.expiresAt,
    this.backupName,
  });

  factory RestoreRequestResponse.fromJson(Map<String, Object?> json) =>
      _$RestoreRequestResponseFromJson(json);

  final int id;
  @JsonKey(name: 'backup_id')
  final int backupId;
  @JsonKey(name: 'backup_created_at')
  final DateTime backupCreatedAt;
  @JsonKey(name: 'requested_by')
  final String requestedBy;
  @JsonKey(name: 'requested_by_me')
  final bool requestedByMe;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  @JsonKey(name: 'backup_name')
  final String? backupName;

  Map<String, Object?> toJson() => _$RestoreRequestResponseToJson(this);
}
