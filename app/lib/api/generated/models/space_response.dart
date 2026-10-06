// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'space_member_response.dart';

part 'space_response.g.dart';

@JsonSerializable()
class SpaceResponse {
  const SpaceResponse({
    required this.spaceId,
    required this.myStatus,
    required this.members,
  });

  factory SpaceResponse.fromJson(Map<String, Object?> json) =>
      _$SpaceResponseFromJson(json);

  @JsonKey(name: 'space_id')
  final int? spaceId;
  @JsonKey(name: 'my_status')
  final String? myStatus;
  final List<SpaceMemberResponse> members;

  Map<String, Object?> toJson() => _$SpaceResponseToJson(this);
}
