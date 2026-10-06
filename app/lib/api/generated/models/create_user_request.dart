// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_user_request.g.dart';

@JsonSerializable()
class CreateUserRequest {
  const CreateUserRequest({
    required this.username,
    required this.email,
    required this.password,
    this.isAdmin = false,
    this.steamId,
  });

  factory CreateUserRequest.fromJson(Map<String, Object?> json) =>
      _$CreateUserRequestFromJson(json);

  final String username;
  final String email;
  final String password;
  @JsonKey(name: 'steam_id')
  final String? steamId;
  @JsonKey(name: 'is_admin')
  final bool isAdmin;

  Map<String, Object?> toJson() => _$CreateUserRequestToJson(this);
}
