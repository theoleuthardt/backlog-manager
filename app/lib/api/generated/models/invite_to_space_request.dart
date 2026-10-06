// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'invite_to_space_request.g.dart';

@JsonSerializable()
class InviteToSpaceRequest {
  const InviteToSpaceRequest({required this.username});

  factory InviteToSpaceRequest.fromJson(Map<String, Object?> json) =>
      _$InviteToSpaceRequestFromJson(json);

  final String username;

  Map<String, Object?> toJson() => _$InviteToSpaceRequestToJson(this);
}
