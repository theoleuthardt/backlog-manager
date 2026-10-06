// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_user_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateUserRequest _$CreateUserRequestFromJson(Map<String, dynamic> json) =>
    CreateUserRequest(
      username: json['username'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      isAdmin: json['is_admin'] as bool? ?? false,
      steamId: json['steam_id'] as String?,
    );

Map<String, dynamic> _$CreateUserRequestToJson(CreateUserRequest instance) =>
    <String, dynamic>{
      'username': instance.username,
      'email': instance.email,
      'password': instance.password,
      'steam_id': instance.steamId,
      'is_admin': instance.isAdmin,
    };
