// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginResult _$LoginResultFromJson(Map<String, dynamic> json) => LoginResult(
  requires2fa: json['requires_2fa'] as bool? ?? false,
  accessToken: json['access_token'] as String?,
  challengeToken: json['challenge_token'] as String?,
);

Map<String, dynamic> _$LoginResultToJson(LoginResult instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'requires_2fa': instance.requires2fa,
      'challenge_token': instance.challengeToken,
    };
