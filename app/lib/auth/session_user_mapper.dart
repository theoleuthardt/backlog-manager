import 'package:backlog_manager/api/generated/export.dart';
import 'package:backlog_manager/routing/session.dart';

/// The part of the account the app keeps in the session. The Steam ID itself
/// stays on the server, only whether one is set is needed.
SessionUser sessionUserFrom(PublicUser user) {
  return SessionUser(
    name: user.name,
    email: user.email,
    setupCompleted: user.setupCompleted,
    defaultSort: user.defaultSort,
    hasSteamId: user.steamId?.isNotEmpty ?? false,
  );
}
