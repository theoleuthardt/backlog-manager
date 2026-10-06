// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'two_factor_login_verify_params.g.dart';

@JsonSerializable()
class TwoFactorLoginVerifyParams {
  const TwoFactorLoginVerifyParams({
    required this.challengeToken,
    required this.code,
  });

  factory TwoFactorLoginVerifyParams.fromJson(Map<String, Object?> json) =>
      _$TwoFactorLoginVerifyParamsFromJson(json);

  @JsonKey(name: 'challenge_token')
  final String challengeToken;
  final String code;

  Map<String, Object?> toJson() => _$TwoFactorLoginVerifyParamsToJson(this);
}
