// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'two_factor_disable_params.g.dart';

@JsonSerializable()
class TwoFactorDisableParams {
  const TwoFactorDisableParams({required this.password});

  factory TwoFactorDisableParams.fromJson(Map<String, Object?> json) =>
      _$TwoFactorDisableParamsFromJson(json);

  final String password;

  Map<String, Object?> toJson() => _$TwoFactorDisableParamsToJson(this);
}
