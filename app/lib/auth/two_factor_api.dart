import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart';
import 'package:backlog_manager/domain/two_factor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The secret of a new authenticator and the address that encodes it for the
/// QR code.
class TwoFactorEnrollment {
  const TwoFactorEnrollment({required this.secret, required this.otpauthUrl});

  final String secret;
  final String otpauthUrl;
}

/// Setting up and turning off two-factor authentication.
abstract interface class TwoFactorApi {
  /// Starts the setup (`POST /api/auth/2fa/enroll`).
  Future<TwoFactorEnrollment> enroll();

  /// Confirms the setup with a code of the authenticator and returns the
  /// backup codes, which are shown once (`POST /api/auth/2fa/verify`).
  Future<List<String>> verify(String code);

  /// Turns two-factor authentication off; it needs the password
  /// (`POST /api/auth/2fa/disable`).
  Future<void> disable(String password);
}

class ApiTwoFactorApi implements TwoFactorApi {
  const ApiTwoFactorApi(this._dio);

  final Future<Dio> Function() _dio;

  Future<FallbackClient> _client() async => RestClient(await _dio()).fallback;

  @override
  Future<TwoFactorEnrollment> enroll() async {
    final response = await (await _client()).apiAuth2FaEnrollEnrollTwoFactor();
    return TwoFactorEnrollment(
      secret: response.secret,
      otpauthUrl: response.otpauthUrl,
    );
  }

  @override
  Future<List<String>> verify(String code) async {
    final response = await (await _client()).apiAuth2FaVerifyVerifyTwoFactor(
      body: TwoFactorVerifyEnrollmentParams(code: normalizeTotpCode(code)),
    );
    return response.backupCodes;
  }

  @override
  Future<void> disable(String password) async {
    await (await _client()).apiAuth2FaDisableDisableTwoFactor(
      body: TwoFactorDisableParams(password: password),
    );
  }
}

final twoFactorApiProvider = Provider<TwoFactorApi>(
  (ref) => ApiTwoFactorApi(() => ref.read(apiDioProvider.future)),
);
