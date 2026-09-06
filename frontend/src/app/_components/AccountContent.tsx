"use client";

import { useState } from "react";
import { toast } from "sonner";
import { QRCodeSVG } from "qrcode.react";
import { useAuth } from "~/app/context/AuthContext";
import {
  useEnrollTwoFactor,
  useVerifyTwoFactorEnrollment,
  useDisableTwoFactor,
} from "~/hooks/useTwoFactor";
import { Button } from "~/components/ui/button";
import { Input } from "~/components/ui/input";
import { Label } from "~/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "~/components/ui/dialog";
import {
  AlertDialog,
  AlertDialogContent,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogCancel,
} from "~/components/ui/alert-dialog";

type EnrollStep = "qr" | "backup-codes";

export function AccountContent() {
  const { user, refreshUser } = useAuth();

  const [isEnrollOpen, setIsEnrollOpen] = useState(false);
  const [enrollStep, setEnrollStep] = useState<EnrollStep>("qr");
  const [code, setCode] = useState("");
  const [backupCodes, setBackupCodes] = useState<string[]>([]);

  const [isDisableOpen, setIsDisableOpen] = useState(false);
  const [disablePassword, setDisablePassword] = useState("");

  const enrollMutation = useEnrollTwoFactor();
  const verifyMutation = useVerifyTwoFactorEnrollment();
  const disableMutation = useDisableTwoFactor();

  if (!user) return null;

  const openEnroll = () => {
    setCode("");
    setEnrollStep("qr");
    enrollMutation.mutate(undefined, {
      onError: (error) => {
        toast.error(error instanceof Error ? error.message : "Failed to start two-factor setup");
        setIsEnrollOpen(false);
      },
    });
    setIsEnrollOpen(true);
  };

  const handleVerify = () => {
    verifyMutation.mutate(code, {
      onSuccess: (codes) => {
        setBackupCodes(codes);
        setEnrollStep("backup-codes");
        void refreshUser();
      },
      onError: (error) => {
        toast.error(error instanceof Error ? error.message : "Invalid two-factor code");
      },
    });
  };

  const closeEnroll = () => {
    setIsEnrollOpen(false);
    setBackupCodes([]);
  };

  const handleDisable = () => {
    disableMutation.mutate(disablePassword, {
      onSuccess: () => {
        toast.success("Two-factor authentication disabled");
        setIsDisableOpen(false);
        setDisablePassword("");
        void refreshUser();
      },
      onError: (error) => {
        toast.error(
          error instanceof Error ? error.message : "Failed to disable two-factor authentication",
        );
      },
    });
  };

  return (
    <div className="flex flex-col gap-8">
      <h1 className="text-3xl font-bold">Account</h1>

      <div className="rounded-lg border border-gray-700 bg-gray-900 p-6">
        <p className="text-sm text-gray-400">Signed in as</p>
        <p className="text-lg font-semibold">{user.name}</p>
        <p className="text-gray-400">{user.email}</p>
      </div>

      <div className="rounded-lg border border-gray-700 bg-gray-900 p-6">
        <h2 className="mb-2 text-xl font-semibold">Two-Factor Authentication</h2>
        <p className="mb-4 text-sm text-gray-400">
          {user.isTwoFactorEnabled
            ? "Two-factor authentication is enabled on your account."
            : "Add an extra layer of security using an authenticator app."}
        </p>
        {user.isTwoFactorEnabled ? (
          <Button variant="outline" onClick={() => setIsDisableOpen(true)}>
            Disable Two-Factor Authentication
          </Button>
        ) : (
          <Button onClick={openEnroll}>Enable Two-Factor Authentication</Button>
        )}
      </div>

      <Dialog open={isEnrollOpen} onOpenChange={(open) => !open && closeEnroll()}>
        <DialogContent>
          {enrollStep === "qr" ? (
            <>
              <DialogHeader>
                <DialogTitle>Set up two-factor authentication</DialogTitle>
                <DialogDescription>
                  Scan the QR code with your authenticator app, then enter the
                  6-digit code it shows.
                </DialogDescription>
              </DialogHeader>
              {enrollMutation.data && (
                <div className="flex flex-col items-center gap-4">
                  <div className="rounded bg-white p-4">
                    <QRCodeSVG value={enrollMutation.data.otpauthUrl} size={192} />
                  </div>
                  <p className="text-muted-foreground text-center text-xs break-all">
                    Can&apos;t scan it? Enter this code manually:{" "}
                    <span className="font-mono">{enrollMutation.data.secret}</span>
                  </p>
                  <div className="w-full">
                    <Label htmlFor="totp-code">6-digit code</Label>
                    <Input
                      id="totp-code"
                      value={code}
                      onChange={(e) => setCode(e.target.value)}
                      placeholder="123456"
                      autoComplete="one-time-code"
                    />
                  </div>
                </div>
              )}
              {enrollMutation.isPending && (
                <p className="text-muted-foreground text-center text-sm">
                  Generating your secret...
                </p>
              )}
              <DialogFooter>
                <Button
                  onClick={handleVerify}
                  disabled={!enrollMutation.data || verifyMutation.isPending || code.length === 0}
                >
                  {verifyMutation.isPending ? "Verifying..." : "Verify and enable"}
                </Button>
              </DialogFooter>
            </>
          ) : (
            <>
              <DialogHeader>
                <DialogTitle>Save your backup codes</DialogTitle>
                <DialogDescription>
                  Store these somewhere safe. Each code can be used once to
                  sign in if you lose access to your authenticator app. They
                  won&apos;t be shown again.
                </DialogDescription>
              </DialogHeader>
              <div className="grid grid-cols-2 gap-2 rounded bg-gray-900 p-4 font-mono text-sm text-white">
                {backupCodes.map((backupCode) => (
                  <span key={backupCode}>{backupCode}</span>
                ))}
              </div>
              <DialogFooter>
                <Button
                  onClick={() => {
                    void navigator.clipboard.writeText(backupCodes.join("\n"));
                    toast.success("Backup codes copied to clipboard");
                  }}
                  variant="outline"
                >
                  Copy codes
                </Button>
                <Button onClick={closeEnroll}>Done</Button>
              </DialogFooter>
            </>
          )}
        </DialogContent>
      </Dialog>

      <AlertDialog open={isDisableOpen} onOpenChange={setIsDisableOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Disable two-factor authentication?</AlertDialogTitle>
            <AlertDialogDescription>
              Enter your password to confirm. Your backup codes will stop
              working.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <div>
            <Label htmlFor="disable-password">Password</Label>
            <Input
              id="disable-password"
              type="password"
              value={disablePassword}
              onChange={(e) => setDisablePassword(e.target.value)}
              autoComplete="current-password"
            />
          </div>
          <AlertDialogFooter>
            <AlertDialogCancel onClick={() => setDisablePassword("")}>
              Cancel
            </AlertDialogCancel>
            <Button
              variant="destructive"
              onClick={handleDisable}
              disabled={disableMutation.isPending || disablePassword.length === 0}
            >
              {disableMutation.isPending ? "Disabling..." : "Disable"}
            </Button>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
