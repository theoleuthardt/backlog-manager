"use client";

import { useState } from "react";
import Image from "next/image";
import { Button } from "shadcn_components/ui/button";
import { X } from "lucide-react";
import { Spinner } from "~/components/ui/spinner";
import { SearchBar } from "./SearchBar";
import { useGameSearch } from "~/hooks/useGameSearch";
import { useCreateMissingGameEntry } from "~/hooks/useCsvImport";
import type { MissingGame } from "~/lib/api/csv";
import type { GameSearchResult } from "~/lib/api/games";

interface MissingGamesModalProps {
  missingGames: MissingGame[];
  isOpen: boolean;
  onClose: () => void;
  onGameSelected?: (gameTitle: string, gameData: GameSearchResult) => void;
}

export const MissingGamesModal = ({
  missingGames,
  isOpen,
  onClose,
}: MissingGamesModalProps) => {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [searchQuery, setSearchQuery] = useState("");
  const [debouncedQuery, setDebouncedQuery] = useState("");

  const gameSearchQuery = useGameSearch(debouncedQuery);

  const searchResults =
    searchQuery.length > 0 ? (gameSearchQuery.data ?? []) : [];

  const createMissingGameMutation = useCreateMissingGameEntry();

  if (!isOpen || missingGames.length === 0) {
    return null;
  }

  const currentGame = missingGames[currentIndex];

  if (!currentGame) {
    return null;
  }

  const handleSelectGame = async (gameData: GameSearchResult) => {
    if (createMissingGameMutation.isPending) return;
    try {
      await createMissingGameMutation.mutateAsync({
        title: gameData.title,
        genre: currentGame.genre,
        platform: currentGame.platform,
        status: currentGame.status,
        imageLink: gameData.imageUrl,
        mainTime: gameData.mainStory,
        mainPlusExtraTime: gameData.mainStoryWithExtras,
        completionTime: gameData.completionist,
      });
      setSearchQuery("");
      if (currentIndex < missingGames.length - 1) {
        setCurrentIndex(currentIndex + 1);
      } else {
        onClose();
      }
    } catch (error) {
      console.error("Failed to create missing game entry:", error);
    }
  };

  const handleSkip = () => {
    setSearchQuery("");

    if (currentIndex < missingGames.length - 1) {
      setCurrentIndex(currentIndex + 1);
    } else {
      onClose();
    }
  };

  return (
    <div className="bg-opacity-50 fixed inset-0 z-50 flex items-center justify-center bg-black">
      <div className="mx-4 w-full max-w-2xl rounded-lg border-2 border-white bg-black p-6 text-white">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-2xl font-bold">
            Missing Game: {currentIndex + 1} of {missingGames.length}
          </h2>
          <button
            onClick={onClose}
            className="text-gray-400 transition-colors hover:text-white"
          >
            <X size={24} />
          </button>
        </div>

        <div className="mb-6 rounded border border-gray-700 bg-gray-900 p-4">
          <p className="text-sm text-gray-400">Game from CSV:</p>
          <p className="text-lg font-semibold">{currentGame.title}</p>
          <div className="mt-2 grid grid-cols-3 gap-4 text-sm text-gray-400">
            <div>Genre: {currentGame.genre}</div>
            <div>Platform: {currentGame.platform}</div>
            <div>Status: {currentGame.status}</div>
          </div>
        </div>

        <div className="mb-6">
          <p className="mb-2 text-sm text-gray-400">
            Search for the game in howLongToBeat:
          </p>
          <div className="flex items-center gap-2">
            <SearchBar
              value={searchQuery}
              placeholder="Search game..."
              onInput={(e) => setSearchQuery(e.currentTarget.value)}
              onDebouncedChange={setDebouncedQuery}
              onClear={() => setSearchQuery("")}
              className="mb-0! flex-1"
            />
            {gameSearchQuery.isPending && (
              <Spinner className="size-6 text-white" />
            )}
          </div>
        </div>

        {searchResults.length > 0 && (
          <div
            className={`mb-6 max-h-64 overflow-y-auto ${createMissingGameMutation.isPending ? "pointer-events-none opacity-50" : ""}`}
          >
            <p className="mb-2 text-sm text-gray-400">Results:</p>
            <div className="space-y-2">
              {searchResults.map((game) => (
                <div
                  key={game.hltbId}
                  className="cursor-pointer rounded border border-gray-700 bg-gray-900 p-3 transition-colors hover:border-white"
                  onClick={() => void handleSelectGame(game)}
                >
                  <div className="flex items-start gap-3">
                    {game.imageUrl && (
                      <Image
                        src={game.imageUrl}
                        alt={game.title}
                        width={48}
                        height={48}
                        className="rounded object-cover"
                      />
                    )}
                    <div className="flex-1">
                      <p className="font-semibold">{game.title}</p>
                      <div className="mt-1 text-xs text-gray-400">
                        <span>Main: {game.mainStory}h</span>
                        <span className="mx-2">|</span>
                        <span>+Extra: {game.mainStoryWithExtras}h</span>
                        <span className="mx-2">|</span>
                        <span>Completionist: {game.completionist}h</span>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="flex justify-end gap-2">
          <Button
            onClick={handleSkip}
            variant="outline"
            className="border-2 border-white bg-white text-black hover:bg-gray-900 hover:text-white"
          >
            Skip
          </Button>
        </div>
      </div>
    </div>
  );
};
