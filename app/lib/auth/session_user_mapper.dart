import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/routing/session.dart';

/// The part of the account the app keeps in the session. Saved secrets (the
/// Steam, IGDB and SteamGridDB keys) stay on the server,
/// only whether they are set is needed.
SessionUser sessionUserFrom(wire.PublicUser user) {
  return SessionUser(
    name: user.name,
    email: user.email,
    setupCompleted: user.setupCompleted,
    id: user.id,
    avatarUpdatedAt: user.avatarUpdatedAt,
    defaultSort: user.defaultSort,
    steamId: user.steamId ?? '',
    steamFamilyIds: user.steamFamilyIds ?? '',
    hasSteamApiKey: user.hasSteamApiKey,
    hasIgdbCredentials: user.hasIgdbCredentials,
    hasSteamgriddbApiKey: user.hasSteamgriddbApiKey,
    steamWishlistAutoSync: user.steamWishlistAutoSync,
    steamWishlistImportedAt: user.steamWishlistImportedAt,
    isTwoFactorEnabled: user.isTwoFactorEnabled,
    theme: user.theme,
    customThemes: [
      for (final theme in user.customThemes ?? const <wire.CustomTheme>[])
        CustomTheme.fromJson(theme.toJson()),
    ],
  );
}
