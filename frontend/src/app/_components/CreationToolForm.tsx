"use client";
import { AchievementProgress, GameImage } from "components/index";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import { Input } from "~/components/ui/input";
import { Label } from "~/components/ui/label";
import { Textarea } from "~/components/ui/textarea";
import { Button } from "~/components/ui/button";
import { Checkbox } from "~/components/ui/checkbox";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "~/components/ui/alert-dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "shadcn_components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "shadcn_components/ui/tabs";
import { StarRating } from "shadcn_components/ui/star-rating";
import { Loader2, Check, X, ArrowLeft } from "lucide-react";
import { StatusSelect } from "components/StatusSelect";
import { useCreateBacklogEntry } from "~/hooks/useBacklog";
import { getEntryDuplicates } from "~/lib/api/backlog";
import type { BacklogEntryData, CreateBacklogEntryInput } from "~/lib/api/backlog";
import { useSteamAppId, useSteamPlaytime } from "~/hooks/useGameSearch";
import { toast } from "sonner";

const NO_SPINNER_CLASS =
  "[appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none";

export function CreationToolForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const isCustomGame = searchParams.get("custom") === "1";
  const titleFromUrl = searchParams.get("title") ?? "";
  const imageUrlFromUrl = searchParams.get("imageUrl") ?? "";
  const descriptionFromUrl = searchParams.get("description") ?? "";
  const publisherFromUrl = searchParams.get("publisher") ?? "";
  const genresFromUrl = searchParams.get("genres") ?? "";
  const platformsFromUrl = searchParams.get("platforms") ?? "";
  const mainStoryFromUrl = Number.parseFloat(
    searchParams.get("mainStory") ?? "0",
  );
  const mainStoryWithExtrasFromUrl = Number.parseFloat(
    searchParams.get("mainStoryWithExtras") ?? "0",
  );
  const completionistFromUrl = Number.parseFloat(
    searchParams.get("completionist") ?? "0",
  );

  const hasHltbData =
    mainStoryFromUrl > 0 ||
    mainStoryWithExtrasFromUrl > 0 ||
    completionistFromUrl > 0;
  const hasMissingData = !imageUrlFromUrl || !hasHltbData;

  const [title, setTitle] = useState(titleFromUrl);
  const [imageUrl, setImageUrl] = useState(imageUrlFromUrl);
  const [genre, setGenre] = useState(genresFromUrl);
  const [status, setStatus] = useState("");
  const [owned, setOwned] = useState(false);
  const [interest, setInterest] = useState(5);
  const [reviewStars, setReviewStars] = useState(0);
  const [review, setReview] = useState("");
  const [note, setNote] = useState("");
  const [playtime, setPlaytime] = useState("0");
  const [steamAppIdInput, setSteamAppIdInput] = useState<string | null>(null);
  const platformOptions = platformsFromUrl
    .split(",")
    .map((p) => p.trim())
    .filter(Boolean);
  const [platform, setPlatform] = useState(
    platformOptions[0] ?? "",
  );
  const [mainStory, setMainStory] = useState(
    Number.isFinite(mainStoryFromUrl) ? String(mainStoryFromUrl) : "0",
  );
  const [mainStoryWithExtras, setMainStoryWithExtras] = useState(
    Number.isFinite(mainStoryWithExtrasFromUrl)
      ? String(mainStoryWithExtrasFromUrl)
      : "0",
  );
  const [completionist, setCompletionist] = useState(
    Number.isFinite(completionistFromUrl) ? String(completionistFromUrl) : "0",
  );
  const [isLoading, setIsLoading] = useState(false);
  const [createStatus, setCreateStatus] = useState<
    "idle" | "success" | "error"
  >("idle");

  const shouldLookUpSteamAppId = !isCustomGame && titleFromUrl.length > 0;
  const steamAppIdQuery = useSteamAppId(shouldLookUpSteamAppId ? title : "");
  const autoSteamAppId = steamAppIdQuery.data;
  const displaySteamAppId =
    steamAppIdInput ?? (autoSteamAppId != null ? String(autoSteamAppId) : "");
  const parsedSteamAppId = Number(displaySteamAppId);
  const resolvedSteamAppId =
    Number.isSafeInteger(parsedSteamAppId) && parsedSteamAppId > 0
      ? parsedSteamAppId
      : undefined;
  const [playtimeTouched, setPlaytimeTouched] = useState(false);
  const steamPlaytimeQuery = useSteamPlaytime(resolvedSteamAppId);
  const steamPlaytime = steamPlaytimeQuery.data;
  const steamPlaytimeHours = steamPlaytime != null ? String(steamPlaytime) : null;
  const effectivePlaytime =
    playtimeTouched || steamPlaytimeHours === null ? playtime : steamPlaytimeHours;

  const createEntryMutation = useCreateBacklogEntry();
  const [duplicates, setDuplicates] = useState<BacklogEntryData[] | null>(null);

  const buildPayload = (): CreateBacklogEntryInput => ({
    title: title.trim(),
    genre: genre.split(",").map((g) => g.trim()).filter(Boolean),
    platform: [platform.trim()].filter(Boolean),
    status,
    owned,
    interest,
    playtime: Number.parseFloat(effectivePlaytime) || 0,
    steamAppId: resolvedSteamAppId,
    imageLink: imageUrl.trim() || undefined,
    mainTime: Number.parseFloat(mainStory) > 0 ? Number.parseFloat(mainStory) : undefined,
    mainPlusExtraTime:
      Number.parseFloat(mainStoryWithExtras) > 0
        ? Number.parseFloat(mainStoryWithExtras)
        : undefined,
    completionTime:
      Number.parseFloat(completionist) > 0
        ? Number.parseFloat(completionist)
        : undefined,
    reviewStars: reviewStars > 0 ? reviewStars : undefined,
    review: review || undefined,
    note: note || undefined,
  });

  const createEntry = async (payload: CreateBacklogEntryInput) => {
    await createEntryMutation.mutateAsync(payload);
    setCreateStatus("success");
    toast.success("Entry created successfully!");
    setTimeout(() => router.push("/dashboard"), 800);
  };

  const handleAddAnyway = async () => {
    setDuplicates(null);
    setIsLoading(true);
    try {
      await createEntry(buildPayload());
    } catch (error) {
      console.error("Error creating backlog entry:", error);
      setCreateStatus("error");
      toast.error(
        error instanceof Error
          ? `Failed to create: ${error.message}`
          : "Failed to create entry. Please try again.",
      );

      setTimeout(() => setCreateStatus("idle"), 3000);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setCreateStatus("idle");

    const payload = buildPayload();
    if (!payload.title) {
      toast.error("Please enter a title");
      return;
    }
    if (payload.genre.length === 0) {
      toast.error("Please enter at least one genre");
      return;
    }
    if (payload.platform.length === 0) {
      toast.error("Please select a platform");
      return;
    }
    if (!payload.status) {
      toast.error("Please select a status");
      return;
    }

    setIsLoading(true);
    try {
      const found = await getEntryDuplicates(
        payload.title,
        payload.steamAppId,
      );
      if (found.length > 0) {
        setDuplicates(found);
        return;
      }
      await createEntry(payload);
    } catch (error) {
      console.error("Error creating backlog entry:", error);
      setCreateStatus("error");
      toast.error(
        error instanceof Error
          ? `Failed to create: ${error.message}`
          : "Failed to create entry. Please try again.",
      );

      setTimeout(() => setCreateStatus("idle"), 3000);
    } finally {
      setIsLoading(false);
    }
  };

  let submitButtonColorClasses =
    "border-white bg-black text-white hover:bg-white hover:text-black";
  if (createStatus === "success") {
    submitButtonColorClasses =
      "border-green-600 bg-green-600 text-white hover:bg-green-600";
  } else if (createStatus === "error") {
    submitButtonColorClasses =
      "border-red-600 bg-red-600 text-white hover:bg-red-600";
  }

  let submitButtonContent: React.ReactNode = "Create Entry";
  if (isLoading) {
    submitButtonContent = (
      <>
        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
        Creating Entry...
      </>
    );
  } else if (createStatus === "success") {
    submitButtonContent = (
      <>
        <Check className="mr-2 h-4 w-4" />
        Created!
      </>
    );
  } else if (createStatus === "error") {
    submitButtonContent = (
      <>
        <X className="mr-2 h-4 w-4" />
        Failed
      </>
    );
  }

  return (
    <div className="mx-auto w-full max-w-[1200px]">
      <h1 className="mb-4 text-center text-2xl font-bold lg:mb-6 lg:text-3xl">
        Creation Tool for <span className="text-blue-500">{title}</span>
      </h1>

      {!isCustomGame && hasMissingData && (
        <div className="mb-4 rounded-lg border-2 border-yellow-600 bg-yellow-900/20 p-4 text-center text-yellow-200">
          <p className="font-semibold">⚠️ Warning: Missing game data</p>
          <p className="text-sm">
            {!imageUrlFromUrl && "No image found. "}
            {!hasHltbData && "No game beat times found. "}
            Consider searching for the game again in the searchbar to get
            complete data.
          </p>
        </div>
      )}

      <form onSubmit={handleSubmit}>
        <div className="flex flex-col gap-6 lg:flex-row lg:gap-8">
          <div className="flex flex-col items-center gap-4 lg:sticky lg:top-24 lg:w-72 lg:self-start lg:shrink-0">
            <GameImage
              src={imageUrl}
              alt={title}
              width={200}
              height={300}
              className="rounded-lg"
            />
            {isCustomGame && (
              <div className="w-full space-y-1">
                <Label htmlFor="imageUrl" className="text-sm">
                  Image URL
                </Label>
                <Input
                  id="imageUrl"
                  value={imageUrl}
                  onChange={(e) => setImageUrl(e.target.value)}
                  placeholder="https://example.com/cover.jpg"
                  className="bg-black text-white"
                />
              </div>
            )}
            {publisherFromUrl && (
              <p className="w-full text-center text-sm text-gray-400">
                Published by{" "}
                <span className="font-semibold text-white">
                  {publisherFromUrl}
                </span>
              </p>
            )}
            {descriptionFromUrl && (
              <div className="w-full rounded-lg border border-gray-700 p-3">
                <p className="mb-1 text-sm font-semibold text-white">About</p>
                <p className="max-h-64 overflow-y-auto text-justify text-sm text-gray-300">
                  {descriptionFromUrl}
                </p>
              </div>
            )}
          </div>

          <div className="min-w-0 flex-1">
            <Tabs defaultValue="details">
              <TabsList className="w-full">
                <TabsTrigger value="details">Details</TabsTrigger>
                <TabsTrigger value="game-data">Game Data</TabsTrigger>
                <TabsTrigger value="review">Review &amp; Notes</TabsTrigger>
              </TabsList>

              <TabsContent value="details" className="mt-4">
                <div className="grid gap-x-6 gap-y-3 sm:grid-cols-2">
                  {isCustomGame && (
                    <div className="space-y-1 sm:col-span-2">
                      <Label htmlFor="title" className="text-sm">
                        Title
                      </Label>
                      <Input
                        id="title"
                        value={title}
                        onChange={(e) => setTitle(e.target.value)}
                        className="bg-black text-white"
                      />
                    </div>
                  )}

                  <div className="space-y-1">
                    <Label htmlFor="platform" className="text-sm">
                      Platform
                    </Label>
                    {platformOptions.length > 0 ? (
                      <Select value={platform} onValueChange={setPlatform}>
                        <SelectTrigger
                          id="platform"
                          className="w-full bg-black text-white"
                        >
                          <SelectValue placeholder="Select a platform" />
                        </SelectTrigger>
                        <SelectContent>
                          {platformOptions.map((platformOption) => (
                            <SelectItem key={platformOption} value={platformOption}>
                              {platformOption}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    ) : (
                      <Input
                        id="platform"
                        value={platform}
                        onChange={(e) => setPlatform(e.target.value)}
                        placeholder="PC, PlayStation, Xbox"
                        className="bg-black text-white"
                      />
                    )}
                  </div>

                  <div className="space-y-1">
                    <Label htmlFor="status" className="text-sm">
                      Status
                    </Label>
                    <StatusSelect
                      value={status}
                      onValueChange={setStatus}
                      className="w-full bg-black text-white"
                    />
                  </div>

                  <div className="space-y-1">
                    <Label htmlFor="genre" className="text-sm">
                      Genre
                    </Label>
                    <Input
                      id="genre"
                      value={genre}
                      onChange={(e) => setGenre(e.target.value)}
                      placeholder="Action, RPG, Adventure"
                      className="bg-black text-white"
                    />
                  </div>

                  <div className="flex items-center space-x-2 pt-6">
                    <Checkbox
                      id="owned"
                      checked={owned}
                      onCheckedChange={(checked) => setOwned(checked as boolean)}
                    />
                    <Label htmlFor="owned" className="cursor-pointer text-sm">
                      I own this game
                    </Label>
                  </div>

                  <div className="space-y-1">
                    <Label htmlFor="playtime" className="text-sm">
                      Playtime (hours)
                      {steamPlaytimeQuery.isFetching && (
                        <Loader2 className="ml-1.5 inline h-3 w-3 animate-spin text-gray-400" />
                      )}
                    </Label>
                    <Input
                      id="playtime"
                      type="number"
                      min="0"
                      step="0.1"
                      value={effectivePlaytime}
                      onChange={(e) => {
                        setPlaytimeTouched(true);
                        setPlaytime(e.target.value);
                      }}
                      className={`${NO_SPINNER_CLASS} bg-black text-white`}
                    />
                  </div>

                  <div className="space-y-1">
                    <Label htmlFor="interest" className="text-sm">
                      Interest Level (1-10)
                    </Label>
                    <Input
                      id="interest"
                      type="number"
                      min="1"
                      max="10"
                      value={interest}
                      onChange={(e) =>
                        setInterest(Number.parseInt(e.target.value) || 1)
                      }
                      className={`${NO_SPINNER_CLASS} bg-black text-white`}
                    />
                  </div>
                </div>
              </TabsContent>

              <TabsContent value="game-data" className="mt-4">
                <div className="grid gap-x-6 gap-y-3 sm:grid-cols-2">
                  <div className="space-y-1 sm:col-span-2">
                    <Label className="text-sm">HowLongToBeat Times</Label>
                    <div className="grid grid-cols-3 gap-2">
                      <div>
                        <Label htmlFor="mainStory" className="mb-1 text-xs">
                          Main
                        </Label>
                        <Input
                          id="mainStory"
                          type="number"
                          step="0.1"
                          min="0"
                          value={mainStory}
                          onChange={(e) => setMainStory(e.target.value)}
                          disabled={!isCustomGame}
                          className={`${NO_SPINNER_CLASS} bg-black text-sm text-white disabled:opacity-70`}
                        />
                      </div>
                      <div>
                        <Label
                          htmlFor="mainStoryWithExtras"
                          className="mb-1 text-xs"
                        >
                          Main+Extra
                        </Label>
                        <Input
                          id="mainStoryWithExtras"
                          type="number"
                          step="0.1"
                          min="0"
                          value={mainStoryWithExtras}
                          onChange={(e) => setMainStoryWithExtras(e.target.value)}
                          disabled={!isCustomGame}
                          className={`${NO_SPINNER_CLASS} bg-black text-sm text-white disabled:opacity-70`}
                        />
                      </div>
                      <div>
                        <Label htmlFor="completionist" className="mb-1 text-xs">
                          Complete
                        </Label>
                        <Input
                          id="completionist"
                          type="number"
                          step="0.1"
                          min="0"
                          value={completionist}
                          onChange={(e) => setCompletionist(e.target.value)}
                          disabled={!isCustomGame}
                          className={`${NO_SPINNER_CLASS} bg-black text-sm text-white disabled:opacity-70`}
                        />
                      </div>
                    </div>
                  </div>

                  <div className="space-y-1">
                    <Label
                      htmlFor="steamAppId"
                      className="flex items-center gap-1.5 text-sm"
                    >
                      Steam App ID (optional)
                      {steamAppIdQuery.isFetching && (
                        <Loader2 className="h-3 w-3 animate-spin text-gray-400" />
                      )}
                    </Label>
                    <Input
                      id="steamAppId"
                      type="number"
                      min="0"
                      value={displaySteamAppId}
                      onChange={(e) => setSteamAppIdInput(e.target.value)}
                      placeholder={
                        isCustomGame
                          ? "e.g. 504230 - enables cover picker and price tracking"
                          : shouldLookUpSteamAppId && steamAppIdQuery.isPending
                            ? "Looking up on Steam..."
                            : "No Steam App ID found - enter one manually"
                      }
                      className={`${NO_SPINNER_CLASS} bg-black text-white`}
                    />
                  </div>

                  <div className="space-y-1 sm:col-span-2">
                    <AchievementProgress steamAppId={resolvedSteamAppId} />
                  </div>
                </div>
              </TabsContent>

              <TabsContent value="review" className="mt-4">
                <div className="grid gap-x-6 gap-y-3 sm:grid-cols-2">
                  <div className="space-y-1">
                    <Label className="text-sm">Review Stars</Label>
                    <StarRating
                      value={reviewStars}
                      onValueChange={setReviewStars}
                      disabled={status !== "Completed"}
                    />
                  </div>

                  <div className="space-y-1">
                    <Label htmlFor="review" className="text-sm">
                      Review
                    </Label>
                    <Textarea
                      id="review"
                      value={review}
                      onChange={(e) => setReview(e.target.value)}
                      placeholder="Write your review here..."
                      disabled={status !== "Completed"}
                      className="min-h-20 resize-none bg-black text-white disabled:opacity-50"
                    />
                  </div>

                  <div className="space-y-1 sm:col-span-2">
                    <Label htmlFor="note" className="text-sm">
                      Notes
                    </Label>
                    <Textarea
                      id="note"
                      value={note}
                      onChange={(e) => setNote(e.target.value)}
                      placeholder="Add any notes about this game..."
                      className="min-h-20 resize-none bg-black text-white"
                    />
                  </div>
                </div>
              </TabsContent>
            </Tabs>

            <div className="mt-6 flex flex-col items-center justify-center gap-2 lg:flex-row lg:justify-end">
              <Button
                type="button"
                onClick={() => router.push("/dashboard")}
                disabled={isLoading}
                className="w-full gap-2 border-2 border-white bg-black px-6 py-5 text-base font-bold text-white hover:bg-white hover:text-black lg:w-auto"
              >
                <ArrowLeft className="h-4 w-4" />
                Search again
              </Button>
              <Button
                type="submit"
                disabled={
                  isLoading ||
                  createStatus === "success" ||
                  (shouldLookUpSteamAppId && steamAppIdQuery.isPending)
                }
                className={`w-full border-2 px-8 py-5 text-base font-bold transition-colors duration-300 lg:w-auto lg:min-w-[200px] ${submitButtonColorClasses}`}
              >
                {submitButtonContent}
              </Button>
            </div>
          </div>
        </div>
      </form>

      <AlertDialog
        open={duplicates !== null}
        onOpenChange={(open) => {
          if (!open) setDuplicates(null);
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Duplicate entries found</AlertDialogTitle>
            <AlertDialogDescription asChild>
              <div>
                You already have {duplicates?.length}{" "}
                {duplicates?.length === 1 ? "entry" : "entries"} for this game
                in your backlog:
                <ul className="mt-2 list-disc pl-5">
                  {duplicates?.map((duplicate) => (
                    <li key={duplicate.id}>
                      <span className="font-semibold">{duplicate.title}</span>
                      {duplicate.platform.length > 0 &&
                        ` (${duplicate.platform.join(", ")}, ${duplicate.status})`}
                    </li>
                  ))}
                </ul>
                Do you want to add this game anyway?
              </div>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Do not Add</AlertDialogCancel>
            <AlertDialogAction onClick={handleAddAnyway}>
              Add Anyway
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}