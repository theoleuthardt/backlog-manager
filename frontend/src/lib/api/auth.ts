import { apiClient, apiErrorMessage } from "./client";
import { clearToken, setToken } from "./token";

export interface CurrentUser {
  id: number;
  name: string;
  email: string;
  isAdmin: boolean;
  isTwoFactorEnabled: boolean;
  createdAt: string;
  updatedAt: string;
  steamId?: string;
  hasSteamApiKey: boolean;
}

export type LoginOutcome =
  | { status: "success" }
  | { status: "requires_2fa"; challengeToken: string };

export async function login(email: string, password: string): Promise<LoginOutcome> {
  const { data, error } = await apiClient.POST("/api/auth/login", {
    body: { email, password },
  });
  if (error) {
    throw new Error(apiErrorMessage(error, "Login failed"));
  }
  if (data.requires_2fa && data.challenge_token) {
    return { status: "requires_2fa", challengeToken: data.challenge_token };
  }
  if (!data.access_token) {
    throw new Error("Login failed");
  }
  setToken(data.access_token);
  return { status: "success" };
}

export function logout(): void {
  clearToken();
}

export async function getCurrentUser(): Promise<CurrentUser> {
  const { data, error } = await apiClient.GET("/api/user/me");
  if (error) {
    throw new Error(apiErrorMessage(error, "Failed to load current user"));
  }
  return {
    id: data.id,
    name: data.name,
    email: data.email,
    isAdmin: data.is_admin,
    isTwoFactorEnabled: data.is_two_factor_enabled,
    createdAt: data.created_at,
    updatedAt: data.updated_at,
    steamId: data.steam_id ?? undefined,
    hasSteamApiKey: data.has_steam_api_key ?? false,
  };
}
