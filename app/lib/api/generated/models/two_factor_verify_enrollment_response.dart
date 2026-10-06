// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'two_factor_verify_enrollment_response.g.dart';

@JsonSerializable()
class TwoFactorVerifyEnrollmentResponse {
  const TwoFactorVerifyEnrollmentResponse({required this.backupCodes});

  factory TwoFactorVerifyEnrollmentResponse.fromJson(
    Map<String, Object?> json,
  ) => _$TwoFactorVerifyEnrollmentResponseFromJson(json);

  @JsonKey(name: 'backup_codes')
  final List<String> backupCodes;

  Map<String, Object?> toJson() =>
      _$TwoFactorVerifyEnrollmentResponseToJson(this);
}
