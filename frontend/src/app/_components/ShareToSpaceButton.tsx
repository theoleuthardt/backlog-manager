import { Link } from "react-router";
import { Loader2, Users } from "lucide-react";
import { toast } from "sonner";
import { Button } from "shadcn_components/ui/button";
import { useBacklogSpaceId } from "~/app/context/BacklogScopeContext";
import { useCreateBacklogEntry } from "~/hooks/useBacklog";
import { useSpace } from "~/hooks/useSpace";
import type { BacklogEntryProps } from "~/app/types";

/**
 * Entry-dialog action of a personal entry: copies it into the shared
 * space, or - once the game is already there - links to the space.
 * Only Steam games can live in a space, so entries without a Steam app
 * id get a disabled button. Renders nothing inside the space itself or
 * for users without an active space.
 */
export function ShareToSpaceButton({ entry }: { entry: BacklogEntryProps }) {
  const scopeSpaceId = useBacklogSpaceId();
  const { data: space } = useSpace();
  const spaceId = space?.myStatus === "active" ? space.spaceId : null;
  const createInSpace = useCreateBacklogEntry(spaceId ?? undefined);

  if (scopeSpaceId !== undefined || spaceId === null) return null;

  if (entry.inSharedSpace) {
    return (
      <Button variant="outline" size="sm" className="gap-2" asChild>
        <Link to="/space">
          <Users className="h-4 w-4" />
          In shared space
        </Link>
      </Button>
    );
  }

  const share = async () => {
    try {
      await createInSpace.mutateAsync({
        title: entry.title,
        genre: entry.genre ?? [],
        platform: entry.platform ?? [],
        status: entry.status ?? "Not Started",
        owned: entry.owned ?? false,
        interest: entry.interest ?? 1,
        imageLink: entry.imageLink || undefined,
        description: entry.description,
        trailerLink: entry.trailerLink,
        mainTime: entry.mainTime,
        mainPlusExtraTime: entry.mainPlusExtraTime,
        completionTime: entry.completionTime,
        playtime: entry.playtime,
        steamAppId: entry.steamAppId,
        reviewStars: entry.reviewStars,
        review: entry.review,
        note: entry.note,
      });
      toast.success(`Added "${entry.title}" to your shared space`);
    } catch (error) {
      toast.error(
        error instanceof Error
          ? error.message
          : "Failed to add the game to your shared space",
      );
    }
  };

  return (
    <Button
      variant="outline"
      size="sm"
      className="gap-2"
      disabled={entry.steamAppId === undefined || createInSpace.isPending}
      title={
        entry.steamAppId === undefined
          ? "Only Steam games can be added to the shared space"
          : undefined
      }
      onClick={() => void share()}
    >
      {createInSpace.isPending ? (
        <Loader2 className="h-4 w-4 animate-spin" />
      ) : (
        <Users className="h-4 w-4" />
      )}
      Add to shared space
    </Button>
  );
}
