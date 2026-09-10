import { apiClient, apiErrorMessage } from "./client";
import type { CurrentUser } from "./auth";
import type { components } from "./schema";

export interface UpdateCurrentUserInput {
  username?: string;
  email?: string;
  password?: string;
  steamId?: string;
  steamApiKey?: string;
  igdbClientId?: string;
  igdbClientSecret?: string;
  steamgriddbApiKey?: string;
  steamAutoImportEnabled?: boolean;
  steamFamilyIds?: string;
}

function toCurrentUser(user: components["schemas"]["PublicUser"]): CurrentUser {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    isAdmin: user.is_admin,
    isTwoFactorEnabled: user.is_two_factor_enabled,
    createdAt: user.created_at,
    updatedAt: user.updated_at,
    steamId: user.steam_id ?? undefined,
    hasSteamApiKey: user.has_steam_api_key ?? false,
    hasIgdbCredentials: user.has_igdb_credentials ?? false,
    hasSteamgriddbApiKey: user.has_steamgriddb_api_key ?? false,
    steamAutoImportEnabled: user.steam_auto_import_enabled ?? false,
    steamFamilyIds: user.steam_family_ids ?? undefined,
  };
}

export async function updateCurrentUser(
  input: UpdateCurrentUserInput,
): Promise<CurrentUser> {
  const { data, error } = await apiClient.PUT("/api/user/me", {
    body: {
      username: input.username,
      email: input.email,
      password: input.password,
      steam_id: input.steamId,
      steam_api_key: input.steamApiKey,
      igdb_client_id: input.igdbClientId,
      igdb_client_secret: input.igdbClientSecret,
      steamgriddb_api_key: input.steamgriddbApiKey,
      steam_auto_import_enabled: input.steamAutoImportEnabled,
      steam_family_ids: input.steamFamilyIds,
    },
  });
  if (error) throw new Error(apiErrorMessage(error, "Failed to update user"));
  return toCurrentUser(data);
}

export async function deleteCurrentUser(): Promise<void> {
  const { error } = await apiClient.DELETE("/api/user/me");
  if (error) throw new Error(apiErrorMessage(error, "Failed to delete user"));
}

export async function getUserByUsername(
  username: string,
): Promise<{ id: number; name: string }> {
  const { data, error } = await apiClient.GET(
    "/api/user/by-username/{username}",
    {
      params: { path: { username } },
    },
  );
  if (error) throw new Error(apiErrorMessage(error, "User not found"));
  return data;
}
