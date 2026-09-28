"use client";
import { useState } from "react";
import { Images, Loader2, XIcon } from "lucide-react";
import { Button } from "shadcn_components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogTitle,
} from "shadcn_components/ui/dialog";
import { GameImage } from "components/GameImage";
import { SearchBar } from "components/SearchBar";
import { Spinner } from "~/components/ui/spinner";
import {
  useSteamGridDbCovers,
  useSteamGridDbCoversById,
  useSteamGridDbSearch,
} from "~/hooks/useGameSearch";

interface CoverPickerDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  steamAppId?: number;
  initialQuery: string;
  onSelect: (url: string) => void;
}

export function CoverPickerDialog({
  open,
  onOpenChange,
  steamAppId,
  initialQuery,
  onSelect,
}: CoverPickerDialogProps) {
  const [steamGridDbGameId, setSteamGridDbGameId] = useState<number | null>(
    null,
  );
  const [searchQuery, setSearchQuery] = useState(initialQuery);
  const [debouncedQuery, setDebouncedQuery] = useState(initialQuery);
  const [wasOpen, setWasOpen] = useState(open);

  if (open !== wasOpen) {
    setWasOpen(open);
    setSteamGridDbGameId(null);
    setSearchQuery(open ? initialQuery : "");
    setDebouncedQuery(open ? initialQuery : "");
  }

  const steamAppIdCovers = useSteamGridDbCovers(
    steamAppId,
    open && steamGridDbGameId === null,
  );
  const searchedCovers = useSteamGridDbCoversById(
    steamGridDbGameId ?? undefined,
    open && steamGridDbGameId !== null,
  );
  const searchResults = useSteamGridDbSearch(debouncedQuery);
  const {
    data: covers,
    isLoading: isLoadingCovers,
    isError: coversFailedToLoad,
  } = steamGridDbGameId !== null ? searchedCovers : steamAppIdCovers;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
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
        <div className="flex items-center gap-2">
          <SearchBar
            value={searchQuery}
            placeholder="Search a different title on SteamGridDB..."
            onInput={(e) => setSearchQuery(e.currentTarget.value)}
            onDebouncedChange={setDebouncedQuery}
            onClear={() => {
              setSearchQuery("");
              setDebouncedQuery("");
            }}
            className="mb-0! flex-1"
          />
          {searchResults.isPending && debouncedQuery && (
            <Spinner className="size-5 text-white" />
          )}
        </div>
        <div className="flex-1 overflow-y-auto pr-1">
          {debouncedQuery && (searchResults.data ?? []).length > 0 ? (
            <div className="space-y-1">
              {(searchResults.data ?? []).map((result) => (
                <button
                  key={result.id}
                  type="button"
                  onClick={() => {
                    setSteamGridDbGameId(result.id);
                    setSearchQuery("");
                    setDebouncedQuery("");
                  }}
                  className="block w-full rounded border border-gray-700 bg-gray-900 p-2 text-left text-sm text-white hover:border-white"
                >
                  {result.name}
                </button>
              ))}
            </div>
          ) : isLoadingCovers ? (
            <div className="flex items-center justify-center py-6">
              <Loader2 className="h-5 w-5 animate-spin" />
            </div>
          ) : coversFailedToLoad ? (
            <p className="text-sm text-red-400">
              Failed to load covers. Please try again.
            </p>
          ) : covers && covers.length > 0 ? (
            <div className="grid grid-cols-[repeat(auto-fill,150px)] justify-center gap-2">
              {covers.map((url) => (
                <button
                  key={url}
                  type="button"
                  onClick={() => onSelect(url)}
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
          ) : steamAppId === undefined && steamGridDbGameId === null ? (
            <p className="text-sm text-white/60">
              No Steam App ID for this entry - search above to find covers for
              it on SteamGridDB.
            </p>
          ) : (
            <p className="text-sm text-white/60">
              No SteamGridDB covers available for this game.
            </p>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
