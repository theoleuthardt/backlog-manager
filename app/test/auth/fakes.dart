import 'package:backlog_manager/auth/auth_api.dart';
import 'package:backlog_manager/auth/token_store.dart';
import 'package:backlog_manager/routing/session.dart';

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

class FakeAuthApi implements AuthApi {
  Future<LoginOutcome> Function(String email, String password)? onLogin;
  Future<String> Function(String challenge, String code)? onVerify;
  Future<SessionUser> Function()? onCurrentUser;
  final calls = <String>[];

  @override
  Future<LoginOutcome> login(String email, String password) {
    calls.add('login $email');
    return onLogin!(email, password);
  }

  @override
  Future<String> verifyLogin(String challengeToken, String code) {
    calls.add('verify $code');
    return onVerify!(challengeToken, code);
  }

  @override
  Future<SessionUser> currentUser() {
    calls.add('me');
    return onCurrentUser!();
  }
}
