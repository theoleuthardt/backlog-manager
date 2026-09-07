import { apiClient, apiErrorMessage } from "./client";
import type { CurrentUser } from "./auth";

export interface UpdateCurrentUserInput {
  username?: string;
  email?: string;
  password?: string;
  steamId?: string;
  steamApiKey?: string;
}

function toCurrentUser(user: {
  id: number;
  name: string;
  email: string;
  is_admin: boolean;
  is_two_factor_enabled: boolean;
  created_at: string;
  updated_at: string;
  steam_id?: string | null;
  has_steam_api_key?: boolean;
}): CurrentUser {
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
