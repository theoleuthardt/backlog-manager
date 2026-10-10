import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The signed-in user as far as the shell needs to know.
class SessionUser {
  const SessionUser({
    required this.name,
    required this.email,
    required this.setupCompleted,
    this.defaultSort = 'status',
    this.steamId = '',
    this.steamFamilyIds = '',
    this.hasSteamApiKey = false,
    this.hasIgdbCredentials = false,
    this.hasSteamgriddbApiKey = false,
    this.hasDiscordWebhookUrl = false,
    this.steamWishlistAutoSync = false,
    this.steamWishlistImportedAt,
    this.isTwoFactorEnabled = false,
  });

  final String name;
  final String email;
  final bool setupCompleted;

  /// The identifier of the sort option the library starts with.
  final String defaultSort;

  /// The SteamID64 of the account, empty when none is linked.
  final String steamId;
  final String steamFamilyIds;

  /// Whether the user saved their own key or credentials. The secrets
  /// themselves never leave the server.
  final bool hasSteamApiKey;
  final bool hasIgdbCredentials;
  final bool hasSteamgriddbApiKey;
  final bool hasDiscordWebhookUrl;

  /// The automatic wishlist sync, which needs the first wishlist import.
  final bool steamWishlistAutoSync;
  final DateTime? steamWishlistImportedAt;
  final bool isTwoFactorEnabled;

  bool get hasSteamId => steamId.isNotEmpty;
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

/// The signed-in user, or null when nobody is signed in.
final sessionUserProvider = Provider<SessionUser?>((ref) {
  final session = ref.watch(sessionProvider);
  return session is SessionSignedIn ? session.user : null;
});
