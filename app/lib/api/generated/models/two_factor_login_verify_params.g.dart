// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'two_factor_login_verify_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TwoFactorLoginVerifyParams _$TwoFactorLoginVerifyParamsFromJson(
  Map<String, dynamic> json,
) => TwoFactorLoginVerifyParams(
  challengeToken: json['challenge_token'] as String,
  code: json['code'] as String,
);

Map<String, dynamic> _$TwoFactorLoginVerifyParamsToJson(
  TwoFactorLoginVerifyParams instance,
) => <String, dynamic>{
  'challenge_token': instance.challengeToken,
  'code': instance.code,
};
