// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'two_factor_verify_enrollment_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TwoFactorVerifyEnrollmentResponse _$TwoFactorVerifyEnrollmentResponseFromJson(
  Map<String, dynamic> json,
) => TwoFactorVerifyEnrollmentResponse(
  backupCodes: (json['backup_codes'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$TwoFactorVerifyEnrollmentResponseToJson(
  TwoFactorVerifyEnrollmentResponse instance,
) => <String, dynamic>{'backup_codes': instance.backupCodes};
