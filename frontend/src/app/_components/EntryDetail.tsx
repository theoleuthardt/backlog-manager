"use client";
import { useState } from "react";
import {
  Check,
  Clock,
  Edit2,
  Flame,
  Images,
  Loader2,
  Trash2,
  X,
  XIcon,
} from "lucide-react";
import { toast } from "sonner";
import { CategoryPicker } from "components/CategoryPicker";
import { GameImage } from "components/GameImage";
import { AchievementProgress } from "components/AchievementProgress";
import { GamePriceSection } from "components/GamePriceSection";
import { StatusSelect } from "components/StatusSelect";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "shadcn_components/ui/alert-dialog";
import { Button } from "shadcn_components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogTitle,
  DialogTrigger,
} from "shadcn_components/ui/dialog";
import { Input } from "shadcn_components/ui/input";
import { Label } from "shadcn_components/ui/label";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "shadcn_components/ui/popover";
import { StarRating } from "shadcn_components/ui/star-rating";
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "shadcn_components/ui/tabs";
import { Textarea } from "shadcn_components/ui/textarea";
import type { BacklogEntryProps } from "~/app/types";
import {
  useDeleteBacklogEntry,
  useUpdateBacklogEntry,
} from "~/hooks/useBacklog";
import { useSteamGridDbCovers } from "~/hooks/useGameSearch";
import { MAX_REVIEW_STARS } from "~/lib/reviewStars";
import { statusColor } from "~/lib/statusStyle";

const INTEREST_SEGMENTS = 10;

function splitList(value: string): string[] {
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

const ChipList = ({ items }: { items: string[] }) =>
  items.length > 0 ? (
    <ul className="flex flex-wrap gap-1.5">
      {items.map((item) => (
        <li
          key={item}
          className="rounded-full border border-white/30 bg-white/10 px-2.5 py-0.5 text-xs font-medium"
        >
          {item}
        </li>
      ))}
    </ul>
  ) : null;

const StatTile = ({
  icon,
  label,
  children,
}: {
  icon: React.ReactNode;
  label: string;
  children: React.ReactNode;
}) => (
  <div className="bg-surface flex flex-col gap-2 rounded-xl border border-white/30 p-3">
    <span className="flex items-center gap-1.5 text-xs font-bold tracking-widest text-white/70 uppercase">
      {icon}
      {label}
    </span>
    {children}
  </div>
);

const TimeBar = ({
  label,
  hours,
  playtime,
}: {
  label: string;
  hours?: number;
  playtime?: number;
}) => {
  const percent =
    hours && hours > 0 ? Math.min(100, ((playtime ?? 0) / hours) * 100) : 0;
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-sm">
        <span className="text-white/70">{label}</span>
        <span className="font-semibold">{hours ? `${hours}h` : "--"}</span>
      </div>
      <div className="h-2 overflow-hidden rounded-full bg-white/15">
        <div
          className="bg-primary h-full rounded-full transition-[width] duration-500"
          style={{ width: `${percent}%` }}
        />
      </div>
    </div>
  );
};

/**
 * Detail dialog content of a backlog entry: a hero with the cover and
 * status, HUD-style stat tiles, and tabs for overview, progress and
 * review, over a fixed action bar. Radix unmounts it while the dialog
 * is closed, so the form state always starts from the entry's current
 * values (e.g. after a drag-and-drop status change).
 */
export const EntryDetail = (props: BacklogEntryProps) => {
  const [imageLink, setImageLink] = useState(props.imageLink);
  const [newImageUrl, setNewImageUrl] = useState("");
  const [playtime, setPlaytime] = useState<number | undefined>(props.playtime);
  const [genre, setGenre] = useState(props.genre?.join(", ") ?? "");
  const [platform, setPlatform] = useState(props.platform?.join(", ") ?? "");
  const [status, setStatus] = useState(props.status ?? "");
  const [owned, setOwned] = useState(props.owned ?? false);
  const [interest, setInterest] = useState(props.interest ?? 0);
  const [reviewStars, setReviewStars] = useState(props.reviewStars ?? 0);
  const [review, setReview] = useState(props.review ?? "");
  const [note, setNote] = useState(props.note ?? "");
  const [isLoading, setIsLoading] = useState(false);
  const [updateStatus, setUpdateStatus] = useState<
    "idle" | "success" | "error"
  >("idle");
  const [imagePopoverOpen, setImagePopoverOpen] = useState(false);
  const [coverPickerOpen, setCoverPickerOpen] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const {
    data: steamGridDbCovers,
    isLoading: isLoadingCovers,
    isError: coversFailedToLoad,
  } = useSteamGridDbCovers(props.steamAppId, coverPickerOpen);

  const updateEntryMutation = useUpdateBacklogEntry();
  const deleteEntryMutation = useDeleteBacklogEntry();

  const handleUpdateImage = () => {
    if (newImageUrl.trim()) {
      setImageLink(newImageUrl);
      setNewImageUrl("");
      setImagePopoverOpen(false);
    }
  };

  const handleSelectCover = async (url: string) => {
    setCoverPickerOpen(false);
    try {
      await updateEntryMutation.mutateAsync({
        entryId: props.id,
        changes: { imageLink: url },
      });
      setImageLink(url);
      toast.success("Cover updated");
    } catch (error) {
      toast.error(
        error instanceof Error
          ? `Failed to update cover: ${error.message}`
          : "Failed to update cover. Please try again.",
      );
    }
  };

  const handleUpdate = async () => {
    setIsLoading(true);
    setUpdateStatus("idle");
    try {
      const changes: {
        imageLink?: string;
        genre?: string[];
        platform?: string[];
        status?: string;
        owned?: boolean;
        interest?: number;
        playtime?: number;
        reviewStars?: number;
        review?: string;
        note?: string;
      } = {};

      if (imageLink !== props.imageLink) changes.imageLink = imageLink;
      if (playtime !== undefined && playtime !== props.playtime)
        changes.playtime = playtime;
      if (genre !== (props.genre?.join(", ") ?? ""))
        changes.genre = splitList(genre);
      if (platform !== (props.platform?.join(", ") ?? ""))
        changes.platform = splitList(platform);
      if (status !== (props.status ?? "")) changes.status = status;
      if (owned !== (props.owned ?? false)) changes.owned = owned;
      if (interest !== (props.interest ?? 0)) changes.interest = interest;
      if (reviewStars !== (props.reviewStars ?? 0))
        changes.reviewStars = reviewStars;
      if (review !== (props.review ?? "")) changes.review = review;
      if (note !== (props.note ?? "")) changes.note = note;

      if (Object.keys(changes).length > 0) {
        await updateEntryMutation.mutateAsync({
          entryId: props.id,
          changes,
        });
        setUpdateStatus("success");
        toast.success("Entry updated successfully!");

        setTimeout(() => setUpdateStatus("idle"), 2000);
      } else {
        toast.info("No changes to update");
        setIsLoading(false);
      }
    } catch (error) {
      console.error("Error updating backlog entry:", error);
      setUpdateStatus("error");
      toast.error(
        error instanceof Error
          ? `Failed to update: ${error.message}`
          : "Failed to update entry. Please try again.",
      );

      setTimeout(() => setUpdateStatus("idle"), 3000);
    } finally {
      setIsLoading(false);
    }
  };

  const handleDelete = async () => {
    setIsDeleting(true);
    try {
      await deleteEntryMutation.mutateAsync(props.id);

      toast.success(`"${props.title}" deleted successfully!`);
      setDeleteDialogOpen(false);
    } catch (error) {
      console.error("Error deleting backlog entry:", error);
      toast.error(
        error instanceof Error
          ? `Failed to delete: ${error.message}`
          : "Failed to delete entry. Please try again.",
      );
    } finally {
      setIsDeleting(false);
    }
  };

  const canReview = status === "Completed";
  const genres = splitList(genre);
  const platforms = splitList(platform);

  return (
    <DialogContent
      className="surface-glow bg-background flex h-dvh w-screen max-w-none flex-col gap-0 overflow-hidden rounded-none border-0 p-0 sm:h-[min(92vh,56rem)] sm:w-[min(96vw,64rem)] sm:max-w-none sm:rounded-2xl sm:border-2 sm:border-white"
      onOpenAutoFocus={(e: { preventDefault: () => void }) => {
        e.preventDefault();
      }}
      showCloseButton={false}
      aria-describedby={undefined}
    >
      <header className="relative shrink-0 overflow-hidden border-b border-white/20">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-0 scale-125 opacity-50 blur-2xl"
        >
          <GameImage src={imageLink} alt="" width={1200} height={500} />
        </div>
        <div
          aria-hidden="true"
          className="from-background via-background/70 to-background/20 absolute inset-0 bg-gradient-to-t"
        />
        <DialogClose asChild>
          <Button
            variant="destructive"
            size="icon"
            aria-label="Close"
            className="absolute top-3 right-3 z-20 h-8 w-8"
          >
            <XIcon className="h-4 w-4 text-black" />
          </Button>
        </DialogClose>
        <div className="relative z-10 flex gap-4 p-4 pr-14 sm:gap-6 sm:p-6">
          <div className="surface-glow shrink-0 self-start rounded-xl">
            <GameImage
              src={imageLink}
              alt={props.imageAlt ?? props.title}
              width={128}
              height={192}
            />
          </div>
          <div className="flex min-w-0 flex-1 flex-col justify-end gap-3">
            <DialogTitle className="text-2xl leading-tight font-extrabold break-words sm:text-4xl">
              {props.title}
            </DialogTitle>
            <div className="flex flex-col gap-2">
              <ChipList items={[...genres, ...platforms]} />
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <span
                aria-hidden="true"
                className="h-3 w-3 rounded-full"
                style={{
                  backgroundColor: statusColor(status),
                  boxShadow: `0 0 10px ${statusColor(status)}`,
                }}
              />
              <StatusSelect
                value={status}
                onValueChange={setStatus}
                className="bg-surface h-9 w-44"
              />
              <GamePriceSection
                steamAppId={props.steamAppId}
                title={props.title}
              />
              <div className="sm:ml-6">
                <CategoryPicker entryId={props.id} />
              </div>
            </div>
          </div>
        </div>
      </header>

      <div className="min-h-0 flex-1 overflow-y-auto p-4 sm:p-6">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <StatTile icon={<Clock className="h-3.5 w-3.5" />} label="Playtime">
            <div className="flex items-center gap-2">
              <Input
                id="playtime"
                type="number"
                min="0"
                aria-label="Playtime in hours"
                value={playtime ?? ""}
                onChange={(e) =>
                  setPlaytime(
                    e.target.value === "" ? undefined : Number(e.target.value),
                  )
                }
                className="h-10 text-lg font-bold"
              />
              <span className="text-sm text-white/70">hours</span>
            </div>
          </StatTile>

          <StatTile icon={<Flame className="h-3.5 w-3.5" />} label="Interest">
            <div
              role="group"
              aria-label="Interest level"
              className="flex items-center gap-1"
            >
              {Array.from({ length: INTEREST_SEGMENTS }, (_, index) => {
                const level = index + 1;
                return (
                  <button
                    key={level}
                    type="button"
                    aria-label={`Interest ${level} of ${INTEREST_SEGMENTS}`}
                    aria-pressed={interest >= level}
                    onClick={() => setInterest(interest === level ? 0 : level)}
                    className={`h-6 flex-1 cursor-pointer rounded-sm transition-colors ${
                      interest >= level
                        ? "bg-primary"
                        : "bg-white/15 hover:bg-white/30"
                    }`}
                  />
                );
              })}
            </div>
            <span className="text-sm text-white/70">
              {interest} / {INTEREST_SEGMENTS}
            </span>
          </StatTile>

          <StatTile icon={<Check className="h-3.5 w-3.5" />} label="Ownership">
            <button
              type="button"
              id="owned"
              role="switch"
              aria-checked={owned}
              onClick={() => setOwned(!owned)}
              className={`flex h-10 cursor-pointer items-center justify-center gap-2 rounded-lg border text-sm font-semibold transition-colors ${
                owned
                  ? "border-primary bg-primary text-primary-foreground"
                  : "border-white/40 hover:bg-white/10"
              }`}
            >
              {owned ? (
                <>
                  <Check className="h-4 w-4" /> In my library
                </>
              ) : (
                "Not owned"
              )}
            </button>
          </StatTile>
        </div>

        <Tabs defaultValue="overview" className="mt-6">
          <TabsList className="w-full sm:w-fit">
            <TabsTrigger value="overview">Overview</TabsTrigger>
            <TabsTrigger value="progress">Progress</TabsTrigger>
            <TabsTrigger value="review">Review &amp; notes</TabsTrigger>
          </TabsList>

          <TabsContent value="overview" className="mt-4 space-y-6">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="genre">Genre (comma-separated)</Label>
                <Input
                  id="genre"
                  value={genre}
                  onChange={(e) => setGenre(e.target.value)}
                  placeholder="RPG, Action, Adventure"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="platform">Platform (comma-separated)</Label>
                <Input
                  id="platform"
                  value={platform}
                  onChange={(e) => setPlatform(e.target.value)}
                  placeholder="PC, PS5, Xbox"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label>Cover</Label>
              <div className="flex flex-wrap gap-2">
                <Popover
                  open={imagePopoverOpen}
                  onOpenChange={setImagePopoverOpen}
                >
                  <PopoverTrigger asChild>
                    <Button variant="outline" size="sm" className="gap-2">
                      <Edit2 className="h-4 w-4" />
                      Update Image
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-64">
                    <div className="space-y-2">
                      <Label htmlFor="image-url">Image URL</Label>
                      <Input
                        id="image-url"
                        placeholder="Enter image URL"
                        value={newImageUrl}
                        onChange={(e) => setNewImageUrl(e.target.value)}
                        onKeyDown={(e) => {
                          if (e.key === "Enter") handleUpdateImage();
                        }}
                      />
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={handleUpdateImage}
                        className="mt-2 w-full gap-2"
                      >
                        Update Image URL
                      </Button>
                    </div>
                  </PopoverContent>
                </Popover>

                {props.steamAppId !== undefined && (
                  <Dialog
                    open={coverPickerOpen}
                    onOpenChange={setCoverPickerOpen}
                  >
                    <DialogTrigger asChild>
                      <Button variant="outline" size="sm" className="gap-2">
                        <Images className="h-4 w-4" />
                        Choose Cover
                      </Button>
                    </DialogTrigger>
                    <DialogContent
                      showCloseButton={false}
                      className="bg-background flex h-[calc(100dvh-2rem)] w-[calc(100vw-2rem)] max-w-6xl flex-col border-2 border-white p-6 sm:h-[calc(100vh-6rem)] sm:max-w-6xl"
                      aria-describedby={undefined}
                    >
                      <DialogClose asChild>
                        <Button
                          variant="destructive"
                          size="icon"
                          aria-label="Close"
                          className="absolute top-4 right-4 z-50 h-8 w-8"
                        >
                          <XIcon className="h-4 w-4 text-black" />
                        </Button>
                      </DialogClose>
                      <DialogTitle className="flex items-center gap-1.5">
                        <Images className="h-4 w-4" />
                        SteamGridDB Covers
                      </DialogTitle>
                      <div className="flex-1 overflow-y-auto pr-1">
                        {isLoadingCovers ? (
                          <div className="flex items-center justify-center py-6">
                            <Loader2 className="h-5 w-5 animate-spin" />
                          </div>
                        ) : coversFailedToLoad ? (
                          <p className="text-sm text-red-400">
                            Failed to load covers. Please try again.
                          </p>
                        ) : steamGridDbCovers &&
                          steamGridDbCovers.length > 0 ? (
                          <div className="grid grid-cols-[repeat(auto-fill,150px)] justify-center gap-2">
                            {steamGridDbCovers.map((url) => (
                              <button
                                key={url}
                                type="button"
                                onClick={() => handleSelectCover(url)}
                                className="overflow-hidden rounded border border-white/20 hover:border-white"
                              >
                                <GameImage
                                  src={url}
                                  alt="Cover option"
                                  width={150}
                                  height={225}
                                />
                              </button>
                            ))}
                          </div>
                        ) : (
                          <p className="text-sm text-white/60">
                            No SteamGridDB covers available for this game.
                          </p>
                        )}
                      </div>
                    </DialogContent>
                  </Dialog>
                )}
              </div>
            </div>
          </TabsContent>

          <TabsContent value="progress" className="mt-4 space-y-6">
            <div className="bg-surface space-y-4 rounded-xl border border-white/30 p-4">
              <h3 className="text-xs font-bold tracking-widest text-white/70 uppercase">
                HowLongToBeat - your {playtime ?? 0}h so far
              </h3>
              <TimeBar
                label="Main story"
                hours={props.mainTime}
                playtime={playtime}
              />
              <TimeBar
                label="Main + extra"
                hours={props.mainPlusExtraTime}
                playtime={playtime}
              />
              <TimeBar
                label="Completionist"
                hours={props.completionTime}
                playtime={playtime}
              />
            </div>
            <AchievementProgress steamAppId={props.steamAppId} />
          </TabsContent>

          <TabsContent value="review" className="mt-4 space-y-4">
            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="note">Note</Label>
                <Textarea
                  id="note"
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  placeholder="Add any notes..."
                  className="min-h-40 resize-none"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="review">Review</Label>
                <StarRating
                  value={reviewStars}
                  onValueChange={setReviewStars}
                  max={MAX_REVIEW_STARS}
                  disabled={!canReview}
                />
                <Textarea
                  id="review"
                  value={review}
                  onChange={(e) => setReview(e.target.value)}
                  disabled={!canReview}
                  placeholder={
                    canReview
                      ? "Write your review here..."
                      : "Set the status to Completed to write a review"
                  }
                  className="min-h-28 resize-none disabled:opacity-50"
                />
              </div>
            </div>
          </TabsContent>
        </Tabs>
      </div>

      <footer className="bg-surface flex shrink-0 items-center justify-between gap-2 border-t border-white/20 p-3 sm:p-4">
        <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
          <AlertDialogTrigger asChild>
            <Button
              variant="destructive"
              size="sm"
              className="gap-2 bg-red-600 text-white hover:bg-red-700"
            >
              <Trash2 className="h-4 w-4" />
              Delete
            </Button>
          </AlertDialogTrigger>
          <AlertDialogContent className="bg-background border-2 border-red-600">
            <AlertDialogHeader>
              <AlertDialogTitle className="text-xl">
                Delete &quot;{props.title}&quot;?
              </AlertDialogTitle>
              <AlertDialogDescription className="text-white/70">
                This action cannot be undone. This will permanently delete this
                backlog entry from your collection.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancel</AlertDialogCancel>
              <AlertDialogAction
                onClick={handleDelete}
                disabled={isDeleting}
                className="bg-red-600 text-white hover:bg-red-700"
              >
                {isDeleting ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Deleting...
                  </>
                ) : (
                  <>
                    <Trash2 className="h-4 w-4" />
                    Delete
                  </>
                )}
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>

        <Button
          id="update-entry-button"
          onClick={handleUpdate}
          disabled={isLoading || updateStatus === "success"}
          className={`min-w-40 gap-2 transition-colors duration-300 ${
            updateStatus === "success"
              ? "bg-green-600 text-white hover:bg-green-600"
              : updateStatus === "error"
                ? "bg-red-600 text-white hover:bg-red-600"
                : ""
          }`}
        >
          {isLoading ? (
            <>
              <Loader2 className="h-4 w-4 animate-spin" />
              Updating...
            </>
          ) : updateStatus === "success" ? (
            <>
              <Check className="h-4 w-4" />
              Updated!
            </>
          ) : updateStatus === "error" ? (
            <>
              <X className="h-4 w-4" />
              Failed
            </>
          ) : (
            "Update Entry"
          )}
        </Button>
      </footer>
    </DialogContent>
  );
};
