"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { AuthCard } from "components/AuthCard";
import { Button } from "~/components/ui/button";
import { Input } from "~/components/ui/input";
import { Label } from "~/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "~/components/ui/select";
import { useAuth } from "~/app/context/AuthContext";
import { useTheme } from "~/app/context/ThemeContext";
import { updateCurrentUser, type UpdateCurrentUserInput } from "~/lib/api/user";
import { isSortOption, SORT_OPTIONS, type SortOption } from "~/lib/sortEntries";
import { BUILTIN_THEMES } from "~/lib/themes";

const STEPS = ["Look & feel", "Steam", "IGDB", "All set"] as const;

const APP_BUTTON =
  "border-2 border-white bg-black text-white hover:bg-white hover:text-black";
const FILLED_BUTTON =
  "border-2 border-white bg-white text-black hover:bg-gray-900 hover:text-white";
const WIZARD_INPUT =
  "h-11 border-white/40 bg-black text-white placeholder:text-gray-500";

export function SetupWizard() {
  const { user, refreshUser } = useAuth();
  const { theme, customThemes, setTheme } = useTheme();
  const router = useRouter();

  const [stepIndex, setStepIndex] = useState(0);
  const [isSaving, setIsSaving] = useState(false);
  const [defaultSort, setDefaultSort] = useState<SortOption>(
    user && isSortOption(user.defaultSort) ? user.defaultSort : "status",
  );
  const [steamId, setSteamId] = useState(user?.steamId ?? "");
  const [steamApiKey, setSteamApiKey] = useState("");
  const [igdbClientId, setIgdbClientId] = useState("");
  const [igdbClientSecret, setIgdbClientSecret] = useState("");

  if (!user) return null;

  const isLastStep = stepIndex === STEPS.length - 1;

  const save = async (input: UpdateCurrentUserInput) => {
    setIsSaving(true);
    try {
      await updateCurrentUser(input);
      return true;
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Failed to save settings",
      );
      return false;
    } finally {
      setIsSaving(false);
    }
  };

  const stepInput = (): UpdateCurrentUserInput => {
    if (stepIndex === 0) return { defaultSort };
    if (stepIndex === 1) {
      return {
        ...(steamId.trim() ? { steamId: steamId.trim() } : {}),
        ...(steamApiKey.trim() ? { steamApiKey: steamApiKey.trim() } : {}),
      };
    }
    if (stepIndex === 2 && igdbClientId.trim() && igdbClientSecret.trim()) {
      return {
        igdbClientId: igdbClientId.trim(),
        igdbClientSecret: igdbClientSecret.trim(),
      };
    }
    return {};
  };

  const handleNext = async () => {
    if (stepIndex === 2 && !igdbClientId.trim() !== !igdbClientSecret.trim()) {
      toast.error("Enter both the IGDB Client ID and Client Secret, or neither");
      return;
    }
    const input = stepInput();
    if (Object.keys(input).length > 0 && !(await save(input))) return;
    setStepIndex((index) => index + 1);
  };

  const finish = async () => {
    if (!(await save({ setupCompleted: true }))) return;
    await refreshUser();
    router.replace("/dashboard");
  };

  const handleThemeChange = (themeId: string) => {
    void setTheme(themeId);
  };

  return (
    <AuthCard
      title={`Welcome, ${user.name}`}
      description={`Step ${stepIndex + 1} of ${STEPS.length}: ${STEPS[stepIndex]}`}
    >
      <div className="flex flex-col gap-5">
        <div className="flex gap-2" aria-hidden="true">
          {STEPS.map((step, index) => (
            <div
              key={step}
              className={`h-1 flex-1 rounded-full ${
                index <= stepIndex ? "bg-white" : "bg-white/20"
              }`}
            />
          ))}
        </div>

        {stepIndex === 0 && (
          <div className="flex flex-col gap-4">
            <div className="flex flex-col gap-2">
              <Label htmlFor="setup-theme">Theme</Label>
              <Select value={theme.id} onValueChange={handleThemeChange}>
                <SelectTrigger id="setup-theme" className="h-11 w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {[...BUILTIN_THEMES, ...customThemes].map((option) => (
                    <SelectItem key={option.id} value={option.id}>
                      {option.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex flex-col gap-2">
              <Label htmlFor="setup-sort">Default dashboard sort</Label>
              <Select
                value={defaultSort}
                onValueChange={(value) => {
                  if (isSortOption(value)) setDefaultSort(value);
                }}
              >
                <SelectTrigger id="setup-sort" className="h-11 w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {SORT_OPTIONS.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        )}

        {stepIndex === 1 && (
          <div className="flex flex-col gap-4">
            <p className="text-sm text-gray-300">
              Optional. Link Steam to import your library and wishlist and to
              sync playtimes. You can do this later in your account settings.
            </p>
            <div className="flex flex-col gap-2">
              <Label htmlFor="setup-steam-id">Steam ID</Label>
              <Input
                id="setup-steam-id"
                value={steamId}
                onChange={(e) => setSteamId(e.target.value)}
                placeholder="17-digit SteamID64"
                className={WIZARD_INPUT}
              />
            </div>
            <div className="flex flex-col gap-2">
              <Label htmlFor="setup-steam-key">Steam Web API key</Label>
              <Input
                id="setup-steam-key"
                type="password"
                value={steamApiKey}
                onChange={(e) => setSteamApiKey(e.target.value)}
                placeholder="Steam Web API key"
                className={WIZARD_INPUT}
              />
            </div>
          </div>
        )}

        {stepIndex === 2 && (
          <div className="flex flex-col gap-4">
            <p className="text-sm text-gray-300">
              Optional. IGDB powers game search and metadata. Without your own
              credentials the server&apos;s are used. Both fields are needed
              together.
            </p>
            <div className="flex flex-col gap-2">
              <Label htmlFor="setup-igdb-id">IGDB Client ID</Label>
              <Input
                id="setup-igdb-id"
                value={igdbClientId}
                onChange={(e) => setIgdbClientId(e.target.value)}
                className={WIZARD_INPUT}
              />
            </div>
            <div className="flex flex-col gap-2">
              <Label htmlFor="setup-igdb-secret">IGDB Client Secret</Label>
              <Input
                id="setup-igdb-secret"
                type="password"
                value={igdbClientSecret}
                onChange={(e) => setIgdbClientSecret(e.target.value)}
                className={WIZARD_INPUT}
              />
            </div>
          </div>
        )}

        {isLastStep && (
          <p className="text-sm text-gray-300">
            You&apos;re ready to go. Everything here can be changed any time in
            your account settings, where you can also enable two-factor
            authentication and set up Discord price alerts.
          </p>
        )}

        <div className="flex items-center justify-between gap-3">
          <Button
            variant="outline"
            className={APP_BUTTON}
            disabled={isSaving || stepIndex === 0}
            onClick={() => setStepIndex((index) => index - 1)}
          >
            Back
          </Button>
          {isLastStep ? (
            <Button
              className={FILLED_BUTTON}
              disabled={isSaving}
              onClick={() => void finish()}
            >
              Go to Dashboard
            </Button>
          ) : (
            <Button
              className={FILLED_BUTTON}
              disabled={isSaving}
              onClick={() => void handleNext()}
            >
              Next
            </Button>
          )}
        </div>

        {!isLastStep && (
          <button
            type="button"
            className="text-center text-sm text-gray-400 underline hover:text-white"
            disabled={isSaving}
            onClick={() => void finish()}
          >
            Skip setup
          </button>
        )}
      </div>
    </AuthCard>
  );
}
