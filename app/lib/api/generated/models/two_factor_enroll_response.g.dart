// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'two_factor_enroll_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TwoFactorEnrollResponse _$TwoFactorEnrollResponseFromJson(
  Map<String, dynamic> json,
) => TwoFactorEnrollResponse(
  secret: json['secret'] as String,
  otpauthUrl: json['otpauth_url'] as String,
);

Map<String, dynamic> _$TwoFactorEnrollResponseToJson(
  TwoFactorEnrollResponse instance,
) => <String, dynamic>{
  'secret': instance.secret,
  'otpauth_url': instance.otpauthUrl,
};
