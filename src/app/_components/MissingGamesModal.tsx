"use client";

import React, { useState } from "react";
import { Button } from "shadcn_components/ui/button";
import { X } from "lucide-react";
import { Spinner } from "~/components/ui/spinner";
import { api } from "~/trpc/react";
import type { MissingGame } from "~/server/csv/parseCSV";

interface GameSearchResult {
  id: number;
  hltbId: number;
  title: string;
  imageUrl: string;
  mainStory: number;
  mainStoryWithExtras: number;
  completionist: number;
}

interface MissingGamesModalProps {
  missingGames: MissingGame[];
  isOpen: boolean;
  onClose: () => void;
  onGameSelected: (gameTitle: string, gameData: GameSearchResult) => void;
}

export const MissingGamesModal = ({
  missingGames,
  isOpen,
  onClose,
  onGameSelected,
}: MissingGamesModalProps) => {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<GameSearchResult[]>([]);
  const [debouncedQuery, setDebouncedQuery] = useState("");

  const gameSearchQuery = api.gameSearch.search.useQuery(
    { searchTerm: debouncedQuery },
    {
      enabled: debouncedQuery.length > 0,
    }
  );

  const createMissingGameMutation = api.csv.createMissingGameEntry.useMutation({
    onSuccess: () => {
      setSearchQuery("");
      setSearchResults([]);
      setDebouncedQuery("");

      // Move to next missing game
      if (currentIndex < missingGames.length - 1) {
        setCurrentIndex(currentIndex + 1);
      } else {
        onClose();
      }
    },
    onError: (error) => {
      console.error("Failed to create missing game entry:", error);
    },
  });

  // Update searchResults when gameSearchQuery data changes
  React.useEffect(() => {
    if (gameSearchQuery.data) {
      setSearchResults(gameSearchQuery.data);
    }
  }, [gameSearchQuery.data]);

  if (!isOpen || missingGames.length === 0) {
    return null;
  }

  const currentGame = missingGames[currentIndex];

  if (!currentGame) {
    return null;
  }

  const handleSelectGame = async (gameData: GameSearchResult) => {
    await createMissingGameMutation.mutateAsync({
      missingGame: currentGame,
      gameData,
    });
  };

  const handleSkip = () => {
    setSearchQuery("");
    setSearchResults([]);
    setDebouncedQuery("");

    if (currentIndex < missingGames.length - 1) {
      setCurrentIndex(currentIndex + 1);
    } else {
      onClose();
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-black border-2 border-white text-white rounded-lg p-6 max-w-2xl w-full mx-4">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-2xl font-bold">
            Missing Game: {currentIndex + 1} of {missingGames.length}
          </h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X size={24} />
          </button>
        </div>

        <div className="mb-6 p-4 bg-gray-900 rounded border border-gray-700">
          <p className="text-sm text-gray-400">Game from CSV:</p>
          <p className="text-lg font-semibold">{currentGame.title}</p>
          <div className="mt-2 text-sm text-gray-400 grid grid-cols-3 gap-4">
            <div>Genre: {currentGame.genre}</div>
            <div>Platform: {currentGame.platform}</div>
            <div>Status: {currentGame.status}</div>
          </div>
        </div>

        <div className="mb-6">
          <p className="text-sm text-gray-400 mb-2">Search for the game in howLongToBeat:</p>
          <div className="flex gap-2 items-center">
            <input
              type="text"
              placeholder="Search game..."
              value={searchQuery}
              onChange={(e) => {
                setSearchQuery(e.target.value);
                if (e.target.value.trim()) {
                  setDebouncedQuery(e.target.value);
                }
              }}
              className="flex-1 px-3 py-2 bg-black border-2 border-white text-white rounded disabled:opacity-50"
            />
            {gameSearchQuery.isPending && (
              <Spinner className="size-6 text-white" />
            )}
          </div>
        </div>

        {searchResults.length > 0 && (
          <div className="mb-6 max-h-64 overflow-y-auto">
            <p className="text-sm text-gray-400 mb-2">Results:</p>
            <div className="space-y-2">
              {searchResults.map((game) => (
                <div
                  key={game.hltbId}
                  className="p-3 bg-gray-900 rounded border border-gray-700 hover:border-white cursor-pointer transition-colors"
                  onClick={() => handleSelectGame(game)}
                >
                  <div className="flex items-start gap-3">
                    {game.imageUrl && (
                      <img
                        src={game.imageUrl}
                        alt={game.title}
                        className="w-12 h-12 object-cover rounded"
                      />
                    )}
                    <div className="flex-1">
                      <p className="font-semibold">{game.title}</p>
                      <div className="text-xs text-gray-400 mt-1">
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

        <div className="flex gap-2 justify-end">
          <Button
            onClick={handleSkip}
            variant="outline"
            className="border-2 border-white text-black bg-white hover:text-white hover:bg-gray-900"
          >
            Skip
          </Button>
        </div>
      </div>
    </div>
  );
};