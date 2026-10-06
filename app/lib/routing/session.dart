import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The signed-in user as far as the shell needs to know.
class SessionUser {
  const SessionUser({
    required this.name,
    required this.email,
    required this.setupCompleted,
  });

  final String name;
  final String email;
  final bool setupCompleted;
}

sealed class SessionState {
  const SessionState();
}

/// The stored token is still being checked.
class SessionLoading extends SessionState {
  const SessionLoading();
}

class SessionSignedOut extends SessionState {
  const SessionSignedOut();
}

class SessionSignedIn extends SessionState {
  const SessionSignedIn(this.user);

  final SessionUser user;
}

/// Holds the session of the app. Signing in and out (token storage, the two
/// factor step, the API calls) is built on this by the sign-in feature.
class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionSignedOut();

  void checking() => state = const SessionLoading();

  void signIn(SessionUser user) => state = SessionSignedIn(user);

  void signOut() => state = const SessionSignedOut();
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);
