"use client";
import {
  Dialog,
  DialogContent,
  DialogTrigger,
  DialogTitle,
  DialogClose,
} from "shadcn_components/ui/dialog";
import { Button } from "shadcn_components/ui/button";
import { GameImage } from "components/GameImage";
import { XIcon, Loader2, Edit2, Check, X, Trash2 } from "lucide-react";
import { useState } from "react";
import { Input } from "shadcn_components/ui/input";
import { Label } from "shadcn_components/ui/label";
import { Textarea } from "shadcn_components/ui/textarea";
import { Checkbox } from "shadcn_components/ui/checkbox";
import { toast } from "sonner";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "shadcn_components/ui/popover";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "shadcn_components/ui/select";
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
import type { BacklogEntryProps } from "~/app/types";
import { api } from "~/trpc/react";

export const BacklogEntry = (props: BacklogEntryProps) => {
  const [imageLink, setImageLink] = useState(props.imageLink);
  const [newImageUrl, setNewImageUrl] = useState("");
  const [playtime, setPlaytime] = useState(props.playtime ?? 0);
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
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const handleUpdateImage = () => {
    if (newImageUrl.trim()) {
      setImageLink(newImageUrl);
      setNewImageUrl("");
      setImagePopoverOpen(false);
    }
  };

  const utils = api.useUtils();
  const updateEntryMutation = api.backlog.updateEntry.useMutation();
  const deleteEntryMutation = api.backlog.deleteEntry.useMutation();

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
        reviewStars?: number;
        review?: string;
        note?: string;
      } = {};

      if (imageLink !== props.imageLink) changes.imageLink = imageLink;
      if (genre !== (props.genre?.join(", ") ?? ""))
        changes.genre = genre
          .split(",")
          .map((g) => g.trim())
          .filter(Boolean);
      if (platform !== (props.platform?.join(", ") ?? ""))
        changes.platform = platform
          .split(",")
          .map((p) => p.trim())
          .filter(Boolean);
      if (status !== (props.status ?? "")) changes.status = status;
      if (owned !== (props.owned ?? false)) changes.owned = owned;
      if (interest !== (props.interest ?? 0)) changes.interest = interest;
      if (reviewStars !== (props.reviewStars ?? 0))
        changes.reviewStars = reviewStars;
      if (review !== (props.review ?? "")) changes.review = review;
      if (note !== (props.note ?? "")) changes.note = note;

      if (Object.keys(changes).length > 0) {
        await updateEntryMutation.mutateAsync({
          backlogEntryId: props.id,
          ...changes,
        });

        await utils.backlog.getEntries.invalidate();

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
      await deleteEntryMutation.mutateAsync({
        backlogEntryId: props.id,
      });

      await utils.backlog.getEntries.invalidate();

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

  return (
    <div
      className={`w-[9.375rem] cursor-pointer rounded-xl ${props.className}`}
    >
      <Dialog>
        <DialogTrigger asChild>
          <div className="leading-[0]">
            <GameImage
              src={props.imageLink ?? ""}
              alt={props.imageAlt ?? ""}
              width={150}
              height={225}
            />
          </div>
        </DialogTrigger>
        <DialogContent
          className="h-[calc(100vh-2rem)] w-[calc(100vw-2rem)] !max-w-none border-2 border-white bg-black p-0"
          onOpenAutoFocus={(e: { preventDefault: () => void }) => {
            e.preventDefault();
          }}
          showCloseButton={false}
        >
          <DialogClose asChild>
            <Button
              variant="destructive"
              size="icon"
              className="absolute top-4 right-4 z-50 h-8 w-8 focus:ring-0 focus:ring-offset-0 focus:outline-none focus-visible:ring-0"
            >
              <XIcon className="h-4 w-4 text-black" />
            </Button>
          </DialogClose>

          <div className="border-b border-white/20 p-6">
            <DialogTitle className="text-center text-3xl text-white">
              {props.title}
            </DialogTitle>
          </div>

          <div
            id="dialog-content-wrapper"
            className="flex h-[calc(100%-5rem)] gap-8 p-6"
          >
            <div
              id="game-image-section"
              className="flex w-64 shrink-0 flex-col items-center gap-4"
            >
              <GameImage
                src={imageLink}
                alt={props.imageAlt ?? ""}
                width={150}
                height={225}
              />
              <Popover
                open={imagePopoverOpen}
                onOpenChange={setImagePopoverOpen}
              >
                <PopoverTrigger asChild>
                  <Button
                    variant="outline"
                    size="sm"
                    className="w-40 gap-2 bg-black text-white hover:bg-white hover:text-black"
                  >
                    <Edit2 className="h-4 w-4" />
                    Update Image
                  </Button>
                </PopoverTrigger>
                <PopoverContent className="w-64 bg-black text-white">
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
                      className="mt-2 w-full gap-2 bg-black text-white hover:bg-white hover:text-black"
                    >
                      Update Image URL
                    </Button>
                  </div>
                </PopoverContent>
              </Popover>
            </div>

            <div id="form-container" className="flex flex-1 flex-col">
              <div
                id="scrollable-form-content"
                className="flex-1 space-y-6 pr-2"
              >
                <div id="basic-info-section" className="grid grid-cols-3 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="playtime" className="text-white">
                      Playtime (in hours)
                    </Label>
                    <Input
                      id="playtime"
                      type="number"
                      value={playtime}
                      onChange={(e) => setPlaytime(Number(e.target.value))}
                      className="bg-black text-white"
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="interest" className="text-white">
                      Interest (0-10)
                    </Label>
                    <Input
                      id="interest"
                      type="number"
                      min="0"
                      max="10"
                      value={interest}
                      onChange={(e) => setInterest(Number(e.target.value))}
                      className="bg-black text-white"
                    />
                  </div>

                  <div className="flex items-end space-x-2 pb-2">
                    <Checkbox
                      id="owned"
                      checked={owned}
                      onCheckedChange={(checked) =>
                        setOwned(checked as boolean)
                      }
                    />
                    <Label htmlFor="owned" className="text-white">
                      Owned
                    </Label>
                  </div>
                </div>

                <div
                  id="genre-platform-status-section"
                  className="grid grid-cols-3 gap-4"
                >
                  <div className="space-y-2">
                    <Label htmlFor="genre" className="text-white">
                      Genre (comma-separated)
                    </Label>
                    <Input
                      id="genre"
                      value={genre}
                      onChange={(e) => setGenre(e.target.value)}
                      placeholder="RPG, Action, Adventure"
                      className="bg-black text-white"
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="platform" className="text-white">
                      Platform (comma-separated)
                    </Label>
                    <Input
                      id="platform"
                      value={platform}
                      onChange={(e) => setPlatform(e.target.value)}
                      placeholder="PC, PS5, Xbox"
                      className="bg-black text-white"
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="status" className="text-white">
                      Status
                    </Label>
                    <Select value={status} onValueChange={setStatus}>
                      <SelectTrigger className="bg-black text-white">
                        <SelectValue placeholder="Select status" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="Not Started">Not Started</SelectItem>
                        <SelectItem value="In Progress">In Progress</SelectItem>
                        <SelectItem value="Completed">Completed</SelectItem>
                        <SelectItem value="On Hold">On Hold</SelectItem>
                        <SelectItem value="Dropped">Dropped</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>

                <div id="hltb-section" className="space-y-2">
                  <Label className="text-white">
                    HowLongToBeat Times (in hours)
                  </Label>
                  <div className="grid grid-cols-3 gap-4">
                    <div className="space-y-2">
                      <Label className="text-sm text-gray-400">
                        Main Story
                      </Label>
                      <div className="flex h-10 items-center rounded-md border border-white/20 bg-black px-3 py-2 text-white">
                        {props.mainTime ?? "--"}
                      </div>
                    </div>
                    <div className="space-y-2">
                      <Label className="text-sm text-gray-400">
                        Main + Extra
                      </Label>
                      <div className="flex h-10 items-center rounded-md border border-white/20 bg-black px-3 py-2 text-white">
                        {props.mainPlusExtraTime ?? "--"}
                      </div>
                    </div>
                    <div className="space-y-2">
                      <Label className="text-sm text-gray-400">
                        Completionist
                      </Label>
                      <div className="flex h-10 items-center rounded-md border border-white/20 bg-black px-3 py-2 text-white">
                        {props.completionTime ?? "--"}
                      </div>
                    </div>
                  </div>
                </div>

                <div id="note-review-section" className="flex gap-4">
                  <div
                    id="note-section"
                    className="flex flex-1 flex-col space-y-2"
                  >
                    <Label htmlFor="note" className="text-white">
                      Note
                    </Label>
                    <Textarea
                      id="note"
                      value={note}
                      onChange={(e) => setNote(e.target.value)}
                      placeholder="Add any notes..."
                      className="flex-1 resize-none bg-black text-white"
                    />
                  </div>

                  <div
                    id="review-container"
                    className="flex flex-1 flex-col gap-6"
                  >
                    <div id="review-stars-section" className="space-y-2">
                      <Label htmlFor="review-stars" className="text-white">
                        Review Stars (0-5)
                      </Label>
                      <Input
                        id="review-stars"
                        type="number"
                        min="0"
                        max="5"
                        step="0.5"
                        value={reviewStars}
                        onChange={(e) => setReviewStars(Number(e.target.value))}
                        disabled={status !== "Completed"}
                        className="bg-black text-white disabled:opacity-50"
                      />
                    </div>

                    <div id="review-section" className="space-y-2">
                      <Label htmlFor="review" className="text-white">
                        Review
                      </Label>
                      <Textarea
                        id="review"
                        value={review}
                        onChange={(e) => setReview(e.target.value)}
                        disabled={status !== "Completed"}
                        placeholder="Write your review here..."
                        className="min-h-[100px] bg-black text-white disabled:opacity-50"
                      />
                    </div>
                  </div>
                </div>

                <div
                  id="update-button-section"
                  className="flex justify-between pt-4 pb-4"
                >
                  <AlertDialog
                    open={deleteDialogOpen}
                    onOpenChange={setDeleteDialogOpen}
                  >
                    <AlertDialogTrigger asChild>
                      <Button
                        variant="destructive"
                        size="sm"
                        className="min-w-[150px] gap-2 bg-red-600 text-white hover:bg-red-700"
                      >
                        <Trash2 className="h-4 w-4" />
                        Delete Entry
                      </Button>
                    </AlertDialogTrigger>
                    <AlertDialogContent className="border-2 border-red-600 bg-black">
                      <AlertDialogHeader>
                        <AlertDialogTitle className="text-xl text-white">
                          Delete &quot;{props.title}&quot;?
                        </AlertDialogTitle>
                        <AlertDialogDescription className="text-gray-300">
                          This action cannot be undone. This will permanently
                          delete this backlog entry from your collection.
                        </AlertDialogDescription>
                      </AlertDialogHeader>
                      <AlertDialogFooter>
                        <AlertDialogCancel className="bg-black text-white hover:bg-gray-800">
                          Cancel
                        </AlertDialogCancel>
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
                    variant="outline"
                    size="sm"
                    onClick={handleUpdate}
                    disabled={isLoading || updateStatus === "success"}
                    className={`min-w-[200px] gap-2 transition-colors duration-300 ${
                      updateStatus === "success"
                        ? "bg-green-600 text-white hover:bg-green-600"
                        : updateStatus === "error"
                          ? "bg-red-600 text-white hover:bg-red-600"
                          : "bg-black text-white hover:bg-white hover:text-black"
                    }`}
                  >
                    {isLoading ? (
                      <>
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        Updating...
                      </>
                    ) : updateStatus === "success" ? (
                      <>
                        <Check className="mr-2 h-4 w-4" />
                        Updated!
                      </>
                    ) : updateStatus === "error" ? (
                      <>
                        <X className="mr-2 h-4 w-4" />
                        Failed
                      </>
                    ) : (
                      "Update Entry"
                    )}
                  </Button>
                </div>
              </div>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
};
