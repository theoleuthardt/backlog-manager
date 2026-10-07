import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart';
import 'package:backlog_manager/auth/session_user_mapper.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class LoginOutcome {
  const LoginOutcome();
}

/// The password was right and the account has no two-factor.
class LoginSucceeded extends LoginOutcome {
  const LoginSucceeded(this.accessToken);

  final String accessToken;
}

/// The password was right; a two-factor code finishes the sign-in.
class LoginNeedsTwoFactor extends LoginOutcome {
  const LoginNeedsTwoFactor(this.challengeToken);

  final String challengeToken;
}

/// The calls the sign-in needs; failures are thrown as `DioException` or
/// `ApiException`.
abstract interface class AuthApi {
  Future<LoginOutcome> login(String email, String password);

  /// Finishes a two-factor sign-in and returns the access token.
  Future<String> verifyLogin(String challengeToken, String code);

  Future<SessionUser> currentUser();
}

/// [AuthApi] over the generated client.
class ApiAuthApi implements AuthApi {
  const ApiAuthApi(this._dio);

  final Future<Dio> Function() _dio;

  Future<FallbackClient> _client() async => RestClient(await _dio()).fallback;

  @override
  Future<LoginOutcome> login(String email, String password) async {
    final result = await (await _client()).apiAuthLoginLogin(
      body: LoginParams(email: email, password: password),
    );
    final challenge = result.challengeToken;
    if (result.requires2fa && challenge != null) {
      return LoginNeedsTwoFactor(challenge);
    }
    final token = result.accessToken;
    if (token == null) throw const ApiException('Login failed');
    return LoginSucceeded(token);
  }

  @override
  Future<String> verifyLogin(String challengeToken, String code) async {
    final result = await (await _client()).apiAuth2FaLoginVerifyLoginVerify(
      body: TwoFactorLoginVerifyParams(
        challengeToken: challengeToken,
        code: code,
      ),
    );
    return result.accessToken;
  }

  @override
  Future<SessionUser> currentUser() async {
    final user = await (await _client()).apiUserMeGetOwnUser();
    return sessionUserFrom(user);
  }
}

final authApiProvider = Provider<AuthApi>(
  (ref) => ApiAuthApi(() => ref.read(apiDioProvider.future)),
);
