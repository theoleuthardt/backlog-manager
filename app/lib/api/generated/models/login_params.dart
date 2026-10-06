// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'login_params.g.dart';

@JsonSerializable()
class LoginParams {
  const LoginParams({required this.email, required this.password});

  factory LoginParams.fromJson(Map<String, Object?> json) =>
      _$LoginParamsFromJson(json);

  final String email;
  final String password;

  Map<String, Object?> toJson() => _$LoginParamsToJson(this);
}
