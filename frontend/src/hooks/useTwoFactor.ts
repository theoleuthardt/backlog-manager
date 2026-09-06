import { useMutation } from "@tanstack/react-query";
import * as twoFactorApi from "~/lib/api/twoFactor";

export function useEnrollTwoFactor() {
  return useMutation({
    mutationFn: twoFactorApi.enrollTwoFactor,
  });
}

export function useVerifyTwoFactorEnrollment() {
  return useMutation({
    mutationFn: twoFactorApi.verifyTwoFactorEnrollment,
  });
}

export function useDisableTwoFactor() {
  return useMutation({
    mutationFn: twoFactorApi.disableTwoFactor,
  });
}
