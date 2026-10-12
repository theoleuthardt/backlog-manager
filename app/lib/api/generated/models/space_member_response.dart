// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'space_member_response.g.dart';

@JsonSerializable()
class SpaceMemberResponse {
  const SpaceMemberResponse({
    required this.username,
    required this.status,
    required this.isMe,
    this.avatarUpdatedAt,
    this.userId = 0,
  });

  factory SpaceMemberResponse.fromJson(Map<String, Object?> json) =>
      _$SpaceMemberResponseFromJson(json);

  final String username;
  final String status;
  @JsonKey(name: 'is_me')
  final bool isMe;
  @JsonKey(name: 'user_id')
  final int userId;
  @JsonKey(name: 'avatar_updated_at')
  final DateTime? avatarUpdatedAt;

  Map<String, Object?> toJson() => _$SpaceMemberResponseToJson(this);
}
