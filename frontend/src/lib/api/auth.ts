import { apiClient, apiErrorMessage } from "./client";
import { clearToken, setToken } from "./token";

export interface CurrentUser {
  id: number;
  name: string;
  email: string;
  isAdmin: boolean;
  createdAt: string;
  updatedAt: string;
}

export async function login(email: string, password: string): Promise<void> {
  const { data, error } = await apiClient.POST("/api/auth/login", {
    body: { email, password },
  });
  if (error) {
    throw new Error(apiErrorMessage(error, "Login failed"));
  }
  setToken(data.access_token);
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
    createdAt: data.created_at,
    updatedAt: data.updated_at,
  };
}
