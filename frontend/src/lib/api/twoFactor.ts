import { apiClient, apiErrorMessage } from "./client";
import { setToken } from "./token";

export interface TwoFactorEnrollment {
  secret: string;
  otpauthUrl: string;
}

export async function enrollTwoFactor(): Promise<TwoFactorEnrollment> {
  const { data, error } = await apiClient.POST("/api/auth/2fa/enroll");
  if (error) throw new Error(apiErrorMessage(error, "Failed to start two-factor setup"));
  return { secret: data.secret, otpauthUrl: data.otpauth_url };
}

function normalizeCode(code: string): string {
  return code.replace(/\s/g, "");
}

export async function verifyTwoFactorEnrollment(code: string): Promise<string[]> {
  const { data, error } = await apiClient.POST("/api/auth/2fa/verify", {
    body: { code: normalizeCode(code) },
  });
  if (error) throw new Error(apiErrorMessage(error, "Invalid two-factor code"));
  return data.backup_codes;
}

export async function disableTwoFactor(password: string): Promise<void> {
  const { error } = await apiClient.POST("/api/auth/2fa/disable", {
    body: { password },
  });
  if (error) throw new Error(apiErrorMessage(error, "Failed to disable two-factor authentication"));
}

export async function verifyTwoFactorLogin(challengeToken: string, code: string): Promise<void> {
  const { data, error } = await apiClient.POST("/api/auth/2fa/login-verify", {
    body: { challenge_token: challengeToken, code: normalizeCode(code) },
  });
  if (error) throw new Error(apiErrorMessage(error, "Invalid two-factor code"));
  setToken(data.access_token);
}
