"use client";

import { useState } from "react";
import { toast } from "sonner";
import { QRCodeSVG } from "qrcode.react";
import { useAuth } from "~/app/context/AuthContext";
import { updateCurrentUser } from "~/lib/api/user";
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

const OUTLINE_BUTTON =
  "border-2 border-white bg-black text-white hover:bg-white hover:text-black";
const FILLED_BUTTON =
  "border-2 border-white bg-white text-black hover:bg-gray-900 hover:text-white";

export function AccountContent() {
  const { user, refreshUser } = useAuth();

  const [isEnrollOpen, setIsEnrollOpen] = useState(false);
  const [enrollStep, setEnrollStep] = useState<EnrollStep>("qr");
  const [code, setCode] = useState("");
  const [backupCodes, setBackupCodes] = useState<string[]>([]);

  const [isDisableOpen, setIsDisableOpen] = useState(false);
  const [disablePassword, setDisablePassword] = useState("");

  const [steamId, setSteamId] = useState("");
  const [steamIdLoadedFor, setSteamIdLoadedFor] = useState<number | null>(null);
  const [isSavingSteamId, setIsSavingSteamId] = useState(false);

  const [steamApiKey, setSteamApiKey] = useState("");
  const [isSavingSteamApiKey, setIsSavingSteamApiKey] = useState(false);

  const enrollMutation = useEnrollTwoFactor();
  const verifyMutation = useVerifyTwoFactorEnrollment();
  const disableMutation = useDisableTwoFactor();

  if (user && steamIdLoadedFor !== user.id) {
    setSteamIdLoadedFor(user.id);
    setSteamId(user.steamId ?? "");
  }

  if (!user) return null;

  const handleSaveSteamId = async () => {
    setIsSavingSteamId(true);
    try {
      await updateCurrentUser({ steamId });
      await refreshUser();
      toast.success("Steam ID saved");
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Failed to save Steam ID",
      );
    } finally {
      setIsSavingSteamId(false);
    }
  };

  const handleSaveSteamApiKey = async () => {
    setIsSavingSteamApiKey(true);
    try {
      await updateCurrentUser({ steamApiKey });
      await refreshUser();
      setSteamApiKey("");
      toast.success("Steam API key saved");
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Failed to save Steam API key",
      );
    } finally {
      setIsSavingSteamApiKey(false);
    }
  };

  const handleRemoveSteamApiKey = async () => {
    setIsSavingSteamApiKey(true);
    try {
      await updateCurrentUser({ steamApiKey: "" });
      await refreshUser();
      toast.success("Steam API key removed");
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Failed to remove Steam API key",
      );
    } finally {
      setIsSavingSteamApiKey(false);
    }
  };

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
    enrollMutation.reset();
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

      <div className="rounded-lg border-2 border-white bg-black p-6">
        <p className="text-sm text-gray-300">Signed in as</p>
        <p className="text-lg font-semibold">{user.name}</p>
        <p className="text-gray-300">{user.email}</p>
      </div>

      <div className="rounded-lg border-2 border-white bg-black p-6">
        <h2 className="mb-2 text-xl font-semibold">Two-Factor Authentication</h2>
        <p className="mb-4 text-sm text-gray-300">
          {user.isTwoFactorEnabled
            ? "Two-factor authentication is enabled on your account."
            : "Add an extra layer of security using an authenticator app."}
        </p>
        {user.isTwoFactorEnabled ? (
          <Button
            variant="outline"
            className={OUTLINE_BUTTON}
            onClick={() => setIsDisableOpen(true)}
          >
            Disable Two-Factor Authentication
          </Button>
        ) : (
          <Button className={FILLED_BUTTON} onClick={openEnroll}>
            Enable Two-Factor Authentication
          </Button>
        )}
      </div>

      <div className="rounded-lg border-2 border-white bg-black p-6">
        <h2 className="mb-2 text-xl font-semibold">Steam</h2>
        <p className="mb-4 text-sm text-gray-300">
          Link your Steam ID to sync playtimes for backlog entries you&apos;ve
          tagged with a Steam App ID.
        </p>
        <div className="flex max-w-sm gap-2">
          <Input
            value={steamId}
            onChange={(e) => setSteamId(e.target.value)}
            placeholder="Steam ID (e.g. 76561197960287930)"
            className="border-white/40 bg-black text-white placeholder:text-gray-500"
          />
          <Button
            className={FILLED_BUTTON}
            onClick={() => void handleSaveSteamId()}
            disabled={isSavingSteamId || steamId === (user.steamId ?? "")}
          >
            {isSavingSteamId ? "Saving..." : "Save"}
          </Button>
        </div>
        <p className="mt-2 text-xs text-gray-500">
          Not sure what this is? Open your Steam profile page and look at
          its URL - if it ends in a long number, that&apos;s your
          SteamID64, paste it above. If it ends in a custom name instead,
          look it up with{" "}
          <a
            href="https://steamdb.com/en/tools/steam-id-finder"
            target="_blank"
            rel="noopener noreferrer"
            className="text-blue-400 underline hover:text-blue-300"
          >
            SteamDB&apos;s SteamID finder
          </a>
          .
        </p>

        <p className="mt-6 mb-2 text-sm text-gray-300">
          {user.hasSteamApiKey
            ? "Your own Steam Web API key is set and used for syncing playtimes."
            : "Optionally set your own Steam Web API key. Falls back to the server's key otherwise."}
        </p>
        <div className="flex max-w-sm gap-2">
          <Input
            type="password"
            value={steamApiKey}
            onChange={(e) => setSteamApiKey(e.target.value)}
            placeholder={
              user.hasSteamApiKey ? "Enter a new key to replace it" : "Steam Web API key"
            }
            className="border-white/40 bg-black text-white placeholder:text-gray-500"
          />
          <Button
            className={FILLED_BUTTON}
            onClick={() => void handleSaveSteamApiKey()}
            disabled={isSavingSteamApiKey || steamApiKey.trim().length === 0}
          >
            {isSavingSteamApiKey ? "Saving..." : "Save"}
          </Button>
          {user.hasSteamApiKey && (
            <Button
              variant="outline"
              className={OUTLINE_BUTTON}
              onClick={() => void handleRemoveSteamApiKey()}
              disabled={isSavingSteamApiKey}
            >
              Remove
            </Button>
          )}
        </div>
      </div>

      <Dialog open={isEnrollOpen} onOpenChange={(open) => !open && closeEnroll()}>
        <DialogContent className="border-2 border-white bg-black text-white">
          {enrollStep === "qr" ? (
            <>
              <DialogHeader>
                <DialogTitle className="text-white">
                  Set up two-factor authentication
                </DialogTitle>
                <DialogDescription className="text-gray-300">
                  Scan the QR code with your authenticator app, then enter the
                  6-digit code it shows.
                </DialogDescription>
              </DialogHeader>
              {enrollMutation.data && (
                <div className="flex flex-col items-center gap-4">
                  <div className="rounded bg-white p-4">
                    <QRCodeSVG value={enrollMutation.data.otpauthUrl} size={192} />
                  </div>
                  <p className="text-center text-xs break-all text-gray-300">
                    Can&apos;t scan it? Enter this code manually:{" "}
                    <span className="font-mono text-white">{enrollMutation.data.secret}</span>
                  </p>
                  <div className="w-full space-y-2">
                    <Label htmlFor="totp-code" className="text-white">
                      6-digit code
                    </Label>
                    <Input
                      id="totp-code"
                      value={code}
                      onChange={(e) => setCode(e.target.value)}
                      placeholder="123456"
                      autoComplete="one-time-code"
                      className="border-white/40 bg-black text-white placeholder:text-gray-300"
                    />
                  </div>
                </div>
              )}
              {enrollMutation.isPending && (
                <p className="text-center text-sm text-gray-300">
                  Generating your secret...
                </p>
              )}
              <DialogFooter>
                <Button
                  className={FILLED_BUTTON}
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
                <DialogTitle className="text-white">Save your backup codes</DialogTitle>
                <DialogDescription className="text-gray-300">
                  Store these somewhere safe. Each code can be used once to
                  sign in if you lose access to your authenticator app. They
                  won&apos;t be shown again.
                </DialogDescription>
              </DialogHeader>
              <div className="grid grid-cols-2 gap-2 rounded border border-white/20 bg-black p-4 font-mono text-sm text-white">
                {backupCodes.map((backupCode) => (
                  <span key={backupCode}>{backupCode}</span>
                ))}
              </div>
              <DialogFooter>
                <Button
                  className={OUTLINE_BUTTON}
                  variant="outline"
                  onClick={() => {
                    navigator.clipboard
                      .writeText(backupCodes.join("\n"))
                      .then(() => toast.success("Backup codes copied to clipboard"))
                      .catch(() =>
                        toast.error("Could not copy the backup codes. Copy them manually."),
                      );
                  }}
                >
                  Copy codes
                </Button>
                <Button className={FILLED_BUTTON} onClick={closeEnroll}>
                  Done
                </Button>
              </DialogFooter>
            </>
          )}
        </DialogContent>
      </Dialog>

      <AlertDialog open={isDisableOpen} onOpenChange={setIsDisableOpen}>
        <AlertDialogContent className="border-2 border-white bg-black">
          <AlertDialogHeader>
            <AlertDialogTitle className="text-white">
              Disable two-factor authentication?
            </AlertDialogTitle>
            <AlertDialogDescription className="text-gray-300">
              Enter your password to confirm. Your backup codes will stop
              working.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <div className="space-y-2">
            <Label htmlFor="disable-password" className="text-white">
              Password
            </Label>
            <Input
              id="disable-password"
              type="password"
              value={disablePassword}
              onChange={(e) => setDisablePassword(e.target.value)}
              autoComplete="current-password"
              className="border-white/40 bg-black text-white"
            />
          </div>
          <AlertDialogFooter>
            <AlertDialogCancel
              className={OUTLINE_BUTTON}
              onClick={() => setDisablePassword("")}
            >
              Cancel
            </AlertDialogCancel>
            <Button
              className={OUTLINE_BUTTON}
              variant="outline"
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
