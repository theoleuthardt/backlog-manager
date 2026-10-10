import 'package:backlog_manager/api/generated/export.dart';
import 'package:backlog_manager/routing/session.dart';

/// The part of the account the app keeps in the session. Saved secrets (the
/// Steam, IGDB and SteamGridDB keys, the Discord webhook) stay on the server,
/// only whether they are set is needed.
SessionUser sessionUserFrom(PublicUser user) {
  return SessionUser(
    name: user.name,
    email: user.email,
    setupCompleted: user.setupCompleted,
    defaultSort: user.defaultSort,
    steamId: user.steamId ?? '',
    steamFamilyIds: user.steamFamilyIds ?? '',
    hasSteamApiKey: user.hasSteamApiKey,
    hasIgdbCredentials: user.hasIgdbCredentials,
    hasSteamgriddbApiKey: user.hasSteamgriddbApiKey,
    hasDiscordWebhookUrl: user.hasDiscordWebhookUrl,
    steamWishlistAutoSync: user.steamWishlistAutoSync,
    steamWishlistImportedAt: user.steamWishlistImportedAt,
  );
}
