// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'two_factor_verify_enrollment_params.g.dart';

@JsonSerializable()
class TwoFactorVerifyEnrollmentParams {
  const TwoFactorVerifyEnrollmentParams({required this.code});

  factory TwoFactorVerifyEnrollmentParams.fromJson(Map<String, Object?> json) =>
      _$TwoFactorVerifyEnrollmentParamsFromJson(json);

  final String code;

  Map<String, Object?> toJson() =>
      _$TwoFactorVerifyEnrollmentParamsToJson(this);
}
