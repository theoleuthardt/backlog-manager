// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'login_result.g.dart';

@JsonSerializable()
class LoginResult {
  const LoginResult({
    this.requires2fa = false,
    this.accessToken,
    this.challengeToken,
  });

  factory LoginResult.fromJson(Map<String, Object?> json) =>
      _$LoginResultFromJson(json);

  @JsonKey(name: 'access_token')
  final String? accessToken;
  @JsonKey(name: 'requires_2fa')
  final bool requires2fa;
  @JsonKey(name: 'challenge_token')
  final String? challengeToken;

  Map<String, Object?> toJson() => _$LoginResultToJson(this);
}
