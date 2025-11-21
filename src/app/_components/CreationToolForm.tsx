"use client";
import { GameImage } from "components/index";
import { useSearchParams } from "next/navigation";
import { useState } from "react";
import { Input } from "~/components/ui/input";
import { Label } from "~/components/ui/label";
import { Textarea } from "~/components/ui/textarea";
import { Button } from "~/components/ui/button";
import { Checkbox } from "~/components/ui/checkbox";
import { Loader2 } from "lucide-react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "~/components/ui/select";

export function CreationToolForm() {
  const searchParams = useSearchParams();
  const title = searchParams.get("title") ?? "";
  const imageUrl = searchParams.get("imageUrl") ?? "";
  const steamAppId = searchParams.get("steamAppId") ?? "";
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
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);

    const entryData = {
      title,
      imageLink: imageUrl,
      steamAppId: parseInt(steamAppId),
      genre: genre
        .split(",")
        .map((g) => g.trim())
        .filter(Boolean),
      platform: platform
        .split(",")
        .map((p) => p.trim())
        .filter(Boolean),
      status,
      owned,
      interest,
      reviewStars,
      review,
      note,
      playtime,
      mainTime: mainStory,
      mainPlusExtraTime: mainStoryWithExtras,
      completionTime: completionist,
    };

    console.log("Submitting entry:", entryData);

    // Simulate API call
    await new Promise((resolve) => setTimeout(resolve, 1000));

    setIsSubmitting(false);
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
                disabled={isSubmitting}
                className="w-full border-2 border-white bg-black px-8 py-5 text-base font-bold text-white hover:bg-white hover:text-black disabled:opacity-50 lg:w-auto lg:min-w-[200px]"
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Creating Entry...
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
