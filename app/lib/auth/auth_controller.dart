import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/auth/auth_api.dart';
import 'package:backlog_manager/auth/token_store.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LoginStep { password, twoFactor }

/// What the sign-in screen shows: the step, the challenge of a two-factor
/// sign-in, whether a request is running and the error banner.
class LoginFlow {
  const LoginFlow({
    this.step = LoginStep.password,
    this.challengeToken,
    this.busy = false,
    this.error,
  });

  final LoginStep step;
  final String? challengeToken;
  final bool busy;
  final String? error;
}

/// Counts the sessions of the app: it grows on every sign-in and sign-out.
/// Providers that hold the data of a user watch it, so nothing of the previous
/// user survives into the next session.
class SessionGenerationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final sessionGenerationProvider =
    NotifierProvider<SessionGenerationNotifier, int>(
      SessionGenerationNotifier.new,
    );

const sessionEndedMessage = 'Your session has ended. Sign in again.';

/// The sign-in state machine: restoring the session at start, signing in with
/// a password and a two-factor code, signing out and dropping an expired
/// session. Every request remembers the session generation it started in, so
/// an answer that arrives after a sign-out cannot bring the old session back.
class AuthController extends Notifier<LoginFlow> {
  @override
  LoginFlow build() => const LoginFlow();

  int get _generation => ref.read(sessionGenerationProvider);

  bool _stale(int generation) => generation != _generation;

  SessionNotifier get _session => ref.read(sessionProvider.notifier);

  /// Checks the stored token at start and signs in with it if it still works.
  Future<void> restore() async {
    final generation = _generation;
    _session.checking();
    final token = await ref.read(tokenStoreProvider).read();
    if (_stale(generation)) return;
    if (token == null) {
      _session.signOut();
      return;
    }
    try {
      final user = await ref.read(authApiProvider).currentUser();
      if (_stale(generation)) return;
      _session.signIn(user);
      ref.read(sessionGenerationProvider.notifier).bump();
    } on Object catch (error) {
      if (_stale(generation)) return;
      final failure = ApiException.from(error, 'Could not check your session');
      if (failure.statusCode == 401) {
        await ref.read(tokenStoreProvider).clear();
        _session.signOut();
      } else {
        _session.signOut();
        state = LoginFlow(error: failure.message);
      }
    }
  }

  Future<void> login(String email, String password) async {
    final generation = _generation;
    state = LoginFlow(
      busy: true,
      step: state.step,
      challengeToken: state.challengeToken,
    );
    try {
      final outcome = await ref.read(authApiProvider).login(email, password);
      if (_stale(generation)) return;
      switch (outcome) {
        case LoginSucceeded(:final accessToken):
          await _complete(accessToken, generation);
        case LoginNeedsTwoFactor(:final challengeToken):
          state = LoginFlow(
            step: LoginStep.twoFactor,
            challengeToken: challengeToken,
          );
      }
    } on Object catch (error) {
      _fail(error, 'Login failed', generation);
    }
  }

  /// Finishes a two-factor sign-in with a code from the app or a backup code;
  /// whitespace is removed first.
  Future<void> verify(String code) async {
    final generation = _generation;
    final challenge = state.challengeToken;
    if (challenge == null) return;
    state = LoginFlow(
      busy: true,
      step: LoginStep.twoFactor,
      challengeToken: challenge,
    );
    try {
      final token = await ref
          .read(authApiProvider)
          .verifyLogin(challenge, code.replaceAll(RegExp(r'\s+'), ''));
      if (_stale(generation)) return;
      await _complete(token, generation);
    } on Object catch (error) {
      _fail(error, 'Verification failed', generation, keepStep: true);
    }
  }

  /// Goes back from the two-factor step to the password form.
  void startOver() => state = const LoginFlow();

  Future<void> signOut() async {
    ref.read(sessionGenerationProvider.notifier).bump();
    await ref.read(tokenStoreProvider).clear();
    _session.signOut();
    state = const LoginFlow();
  }

  /// A request answered 401: the token is no longer valid. A signed-in user
  /// is signed out with a notice; a failed sign-in keeps its own error.
  Future<void> sessionExpired() async {
    if (ref.read(sessionProvider) is! SessionSignedIn) return;
    await signOut();
    state = const LoginFlow(error: sessionEndedMessage);
  }

  /// Reads the user again, for example after the account was changed.
  Future<void> refreshUser() async {
    final generation = _generation;
    final user = await ref.read(authApiProvider).currentUser();
    final signedIn = ref.read(sessionProvider) is SessionSignedIn;
    if (_stale(generation) || !signedIn) return;
    _session.signIn(user);
  }

  Future<void> _complete(String token, int generation) async {
    final store = ref.read(tokenStoreProvider);
    await store.write(token);
    if (_stale(generation)) {
      await store.clear();
      return;
    }
    try {
      final user = await ref.read(authApiProvider).currentUser();
      if (_stale(generation)) return;
      _session.signIn(user);
      ref.read(sessionGenerationProvider.notifier).bump();
      state = const LoginFlow();
    } on Object {
      await store.clear();
      rethrow;
    }
  }

  void _fail(
    Object error,
    String fallback,
    int generation, {
    bool keepStep = false,
  }) {
    if (_stale(generation)) return;
    state = LoginFlow(
      step: keepStep ? state.step : LoginStep.password,
      challengeToken: keepStep ? state.challengeToken : null,
      error: ApiException.from(error, fallback).message,
    );
  }
}

final authControllerProvider = NotifierProvider<AuthController, LoginFlow>(
  AuthController.new,
);
