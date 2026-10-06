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
  });

  factory SpaceMemberResponse.fromJson(Map<String, Object?> json) =>
      _$SpaceMemberResponseFromJson(json);

  final String username;
  final String status;
  @JsonKey(name: 'is_me')
  final bool isMe;

  Map<String, Object?> toJson() => _$SpaceMemberResponseToJson(this);
}
