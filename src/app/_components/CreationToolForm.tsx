"use client";
import { GameImage } from "components/index";
import { useSearchParams } from "next/navigation";
import { useState } from "react";
import { Input } from "~/components/ui/input";
import { Label } from "~/components/ui/label";
import { Textarea } from "~/components/ui/textarea";
import { Button } from "~/components/ui/button";
import { Checkbox } from "~/components/ui/checkbox";
import { Loader2, Check, X } from "lucide-react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "~/components/ui/select";
import { api } from "~/trpc/react";
import { toast } from "sonner";

export function CreationToolForm() {
  const searchParams = useSearchParams();
  const title = searchParams.get("title") ?? "";
  const imageUrl = searchParams.get("imageUrl") ?? "";
  const mainStory = parseFloat(searchParams.get("mainStory") ?? "0");
  const mainStoryWithExtras = parseFloat(
    searchParams.get("mainStoryWithExtras") ?? "0",
  );
  const completionist = parseFloat(searchParams.get("completionist") ?? "0");

  const [genre, setGenre] = useState("");
  const [platform, setPlatform] = useState("");
  const [status, setStatus] = useState("");
  const [owned, setOwned] = useState(false);
  const [interest, setInterest] = useState(5);
  const [reviewStars, setReviewStars] = useState(0);
  const [review, setReview] = useState("");
  const [note, setNote] = useState("");
  const [playtime, setPlaytime] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [createStatus, setCreateStatus] = useState<
    "idle" | "success" | "error"
  >("idle");

  const createEntryMutation = api.backlog.createEntry.useMutation();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setCreateStatus("idle");

    try {
      if (!genre.trim()) {
        toast.error("Please enter at least one genre");
        setIsLoading(false);
        return;
      }
      if (!platform.trim()) {
        toast.error("Please enter at least one platform");
        setIsLoading(false);
        return;
      }
      if (!status) {
        toast.error("Please select a status");
        setIsLoading(false);
        return;
      }

      const statusMap: Record<
        string,
        "Backlog" | "Playing" | "Completed" | "Dropped"
      > = {
        "Not Started": "Backlog",
        "In Progress": "Playing",
        Completed: "Completed",
        Dropped: "Dropped",
      };

      const mappedStatus = statusMap[status] ?? "Backlog";

      await createEntryMutation.mutateAsync({
        title,
        genre,
        platform,
        status: mappedStatus,
        owned,
        interest,
        imageLink: imageUrl,
        mainTime: mainStory || undefined,
        mainPlusExtraTime: mainStoryWithExtras || undefined,
        completionTime: completionist || undefined,
        reviewStars: reviewStars || undefined,
        review: review || undefined,
        note: note || undefined,
      });

      setCreateStatus("success");
      toast.success("Entry created successfully!");

      setTimeout(() => setCreateStatus("idle"), 2000);
    } catch (error) {
      console.error("❌ Error creating backlog entry:", error);
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

  return (
    <div className="mx-auto w-full max-w-[1600px]">
      <h1 className="mb-4 text-center text-2xl font-bold lg:mb-6 lg:text-3xl">
        Creation Tool for <span className="text-blue-500">{title}</span>
      </h1>

      <form onSubmit={handleSubmit}>
        <div className="flex flex-col gap-4 lg:flex-row lg:gap-8">
          <div className="flex justify-center lg:w-64 lg:flex-shrink-0">
            <GameImage
              src={imageUrl}
              alt={title}
              width={180}
              height={270}
              className="rounded-lg"
            />
          </div>

          <div className="flex-1">
            <div className="grid gap-x-6 gap-y-3 lg:grid-cols-2">
              <div className="space-y-1 lg:col-span-2">
                <Label className="text-sm">HowLongToBeat Times</Label>
                <div className="grid grid-cols-3 gap-2">
                  <div>
                    <Label htmlFor="mainStory" className="mb-1 text-xs">
                      Main
                    </Label>
                    <Input
                      id="mainStory"
                      type="number"
                      value={mainStory}
                      disabled
                      className="[appearance:textfield] bg-black text-sm text-white [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
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
                      value={mainStoryWithExtras}
                      disabled
                      className="[appearance:textfield] bg-black text-sm text-white [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
                    />
                  </div>
                  <div>
                    <Label htmlFor="completionist" className="mb-1 text-xs">
                      Complete
                    </Label>
                    <Input
                      id="completionist"
                      type="number"
                      value={completionist}
                      disabled
                      className="[appearance:textfield] bg-black text-sm text-white [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
                    />
                  </div>
                </div>
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

              <div className="space-y-1">
                <Label htmlFor="platform" className="text-sm">
                  Platform
                </Label>
                <Input
                  id="platform"
                  value={platform}
                  onChange={(e) => setPlatform(e.target.value)}
                  placeholder="PC, PlayStation, Xbox"
                  className="bg-black text-white"
                />
              </div>

              <div className="space-y-1">
                <Label htmlFor="status" className="text-sm">
                  Status
                </Label>
                <Select value={status} onValueChange={setStatus}>
                  <SelectTrigger className="w-full bg-black text-white">
                    <SelectValue placeholder="Select status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Not Started">Not Started</SelectItem>
                    <SelectItem value="In Progress">In Progress</SelectItem>
                    <SelectItem value="Dropped">Dropped</SelectItem>
                    <SelectItem value="Completed">Completed</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1">
                <Label htmlFor="playtime" className="text-sm">
                  Playtime (hours)
                </Label>
                <Input
                  id="playtime"
                  type="number"
                  min="0"
                  step="0.1"
                  value={playtime}
                  onChange={(e) => setPlaytime(parseFloat(e.target.value) || 0)}
                  className="bg-black text-white"
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
                  onChange={(e) => setInterest(parseInt(e.target.value) || 1)}
                  className="bg-black text-white"
                />
              </div>

              <div className="space-y-1">
                <Label htmlFor="reviewStars" className="text-sm">
                  Review Stars (0-5)
                </Label>
                <Input
                  id="reviewStars"
                  type="number"
                  min="0"
                  max="5"
                  step="0.5"
                  value={reviewStars}
                  onChange={(e) =>
                    setReviewStars(parseFloat(e.target.value) || 0)
                  }
                  disabled={status !== "Completed"}
                  className="bg-black text-white disabled:opacity-50"
                />
              </div>

              <div className="flex items-center space-x-2 lg:col-span-2">
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
                <Label htmlFor="note" className="text-sm">
                  Notes
                </Label>
                <Textarea
                  id="note"
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  placeholder="Add any notes about this game..."
                  className="min-h-[80px] resize-none bg-black text-white"
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
                  className="min-h-[80px] resize-none bg-black text-white disabled:opacity-50"
                />
              </div>
            </div>

            <div className="mt-4 flex justify-center lg:justify-end">
              <Button
                type="submit"
                disabled={isLoading || createStatus === "success"}
                className={`w-full border-2 px-8 py-5 text-base font-bold transition-colors duration-300 lg:w-auto lg:min-w-[200px] ${
                  createStatus === "success"
                    ? "border-green-600 bg-green-600 text-white hover:bg-green-600"
                    : createStatus === "error"
                      ? "border-red-600 bg-red-600 text-white hover:bg-red-600"
                      : "border-white bg-black text-white hover:bg-white hover:text-black"
                }`}
              >
                {isLoading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Creating Entry...
                  </>
                ) : createStatus === "success" ? (
                  <>
                    <Check className="mr-2 h-4 w-4" />
                    Created!
                  </>
                ) : createStatus === "error" ? (
                  <>
                    <X className="mr-2 h-4 w-4" />
                    Failed
                  </>
                ) : (
                  "Create Entry"
                )}
              </Button>
            </div>
          </div>
        </div>
      </form>
    </div>
  );
}
