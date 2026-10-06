import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogTitle,
} from "shadcn_components/ui/dialog";
import { GameImage } from "components/GameImage";
import { SearchBar } from "components/SearchBar";
import { Button } from "shadcn_components/ui/button";
import { Spinner } from "~/components/ui/spinner";
import { useGameSearch } from "~/hooks/useGameSearch";
import type { GameSearchResult } from "~/lib/api/games";

interface WrongGameDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  initialQuery?: string;
  onSelect: (result: GameSearchResult) => void;
}

export function WrongGameDialog({
  open,
  onOpenChange,
  initialQuery = "",
  onSelect,
}: WrongGameDialogProps) {
  const [searchQuery, setSearchQuery] = useState("");
  const [debouncedQuery, setDebouncedQuery] = useState("");
  const [wasOpen, setWasOpen] = useState(open);
  const [deepSearch, setDeepSearch] = useState(false);
  const gameSearch = useGameSearch(debouncedQuery, deepSearch);

  if (open !== wasOpen) {
    setWasOpen(open);
    if (open) {
      setSearchQuery(initialQuery);
      setDebouncedQuery(initialQuery);
      setDeepSearch(false);
    }
  }

  const handleDebouncedChange = (value: string) => {
    if (value !== debouncedQuery) setDeepSearch(false);
    setDebouncedQuery(value);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        className="bg-background flex max-h-[80vh] w-full max-w-xl flex-col gap-4 border-2 border-white p-6"
        aria-describedby={undefined}
      >
        <DialogTitle>Find the right game</DialogTitle>
        <div className="flex items-center gap-2">
          <SearchBar
            value={searchQuery}
            placeholder="Search game..."
            onInput={(e) => setSearchQuery(e.currentTarget.value)}
            onDebouncedChange={handleDebouncedChange}
            onClear={() => setSearchQuery("")}
            className="mb-0! flex-1"
          />
          {gameSearch.isPending && debouncedQuery && (
            <Spinner className="size-6 text-white" />
          )}
        </div>
        <div className="flex-1 space-y-2 overflow-y-auto">
          {(gameSearch.data ?? []).map((result) => (
            <button
              key={result.id}
              type="button"
              onClick={() => onSelect(result)}
              className="flex w-full items-start gap-3 rounded border border-gray-700 bg-gray-900 p-3 text-left transition-colors hover:border-white"
            >
              <GameImage
                src={result.imageUrl ?? ""}
                alt={result.title}
                width={48}
                height={48}
              />
              <div className="flex-1">
                <p className="font-semibold text-white">{result.title}</p>
                <div className="mt-1 text-xs text-gray-400">
                  <span>Main: {result.mainStory}h</span>
                  <span className="mx-2">|</span>
                  <span>+Extra: {result.mainStoryWithExtras}h</span>
                  <span className="mx-2">|</span>
                  <span>Completionist: {result.completionist}h</span>
                </div>
              </div>
            </button>
          ))}
          {debouncedQuery &&
            !gameSearch.isPending &&
            (gameSearch.data ?? []).length === 0 && (
              <p className="text-sm text-gray-400">No results found.</p>
            )}
          {debouncedQuery && !deepSearch && !gameSearch.isPending && (
            <Button
              type="button"
              variant="outline"
              className="w-full"
              onClick={() => setDeepSearch(true)}
            >
              Can&apos;t find your game? Search more
            </Button>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
