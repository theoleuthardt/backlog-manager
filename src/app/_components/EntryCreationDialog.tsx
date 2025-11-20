"use client";
import * as React from "react";
import Image from "next/image";
import Link from "next/link";
import {
  Dialog,
  DialogHeader,
  DialogPortal,
  DialogTitle,
  DialogTrigger,
} from "~/components/ui/dialog";
import { GameImage, SearchBar } from "components";
import * as DialogPrimitive from "@radix-ui/react-dialog";
import { cn } from "~/lib/utils";
import { Button } from "~/components/ui/button";
import { gameSearchbarDummyResults } from "~/constants";
import type { GameSearchResult, EntryCreationDialogProps } from "~/types";

export const EntryCreationDialog = ({
  triggerIcon = "/search.png",
  triggerAlt = "search",
  triggerClassName = "",
  showText = true,
}: EntryCreationDialogProps = {}) => {
  const [searchQuery, setSearchQuery] = React.useState("");
  const [resultsVisible, setResultsVisible] = React.useState(false);
  const [searchResults, setSearchResults] = React.useState<GameSearchResult[]>([]);
  const [selectedIndex, setSelectedIndex] = React.useState<number | null>(null);

  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button
          id={"add-entry-button"}
          className={`border-0 text-white ${triggerClassName}`}
          variant="outline"
          disabled={false}
        >
          <Image src={triggerIcon} alt={triggerAlt} width={32} height={32} />
          {showText && "Add Entry"}
        </Button>
      </DialogTrigger>
      <DialogPortal>
        <DialogPrimitive.Overlay
          className={cn(
            "data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed inset-0 z-50 bg-black/50 backdrop-blur-md",
          )}
        />
        <DialogPrimitive.Content
          className={cn(
            "bg-background data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 fixed left-[50%] z-50 grid w-full max-w-[calc(100%-2rem)] translate-x-[-50%] gap-4 rounded-lg p-6 duration-500 sm:max-w-lg",
            "w-full justify-center-safe bg-transparent md:w-[80rem] lg:w-[100rem]",
            resultsVisible && searchResults.length > 0
              ? "top-8 max-h-[calc(100vh-4rem)] translate-y-0"
              : "top-[50%] h-[10rem] translate-y-[-50%]",
          )}
          onOpenAutoFocus={(e) => e.preventDefault()}
        >
          <div className="flex flex-col items-center gap-4">
            <DialogHeader>
              <DialogTitle className="text-center text-3xl text-white">
                Search for a game 🎮:
              </DialogTitle>
            </DialogHeader>
            <div className="w-full max-w-2xl px-4">
              <SearchBar
                useIcon={false}
                placeholder="Type in a game name..."
                value={searchQuery}
                onInput={(e: React.ChangeEvent<HTMLInputElement>) => {
                  const query = e.target.value;
                  setSearchQuery(query);
                  if (query.length > 0) {
                    setResultsVisible(true);
                    setSearchResults(gameSearchbarDummyResults);
                  } else {
                    setResultsVisible(false);
                    setSearchResults([]);
                    setSelectedIndex(null);
                  }
                }}
                onClear={() => {
                  setSearchQuery("");
                  setResultsVisible(false);
                  setSearchResults([]);
                  setSelectedIndex(null);
                }}
                className="mx-auto text-white"
              />
            </div>
          </div>
          {resultsVisible && searchResults.length > 0 && (
            <div className="flex flex-col items-center gap-6">
              <ul className="flex max-h-96 w-full max-w-2xl flex-col gap-2 overflow-y-auto bg-transparent">
                {searchResults.map((result, index) => (
                  <li
                    key={index}
                    onClick={() => setSelectedIndex(index)}
                    className={cn(
                      "group flex cursor-pointer items-center gap-2 rounded-xl p-2 transition-all duration-300 ease-in-out",
                      selectedIndex === index
                        ? "border-2 border-blue-600"
                        : "border-2 border-transparent",
                    )}
                  >
                    <div className="flex flex-row items-center gap-2">
                      <GameImage
                        src={result.imageUrl}
                        alt={result.title}
                        width={60}
                        height={90}
                        className="rounded-lg"
                      />
                      <div className="ml-5 flex items-center justify-center text-lg font-semibold text-white transition-colors duration-300 group-hover:text-blue-600">
                        {result.title}
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
              {selectedIndex !== null && searchResults[selectedIndex] && (
                <Link
                  href={{
                    pathname: "/creation-tool",
                    query: {
                      title: searchResults[selectedIndex].title,
                      imageUrl: searchResults[selectedIndex].imageUrl,
                      steamAppId: searchResults[selectedIndex].steamAppId,
                      mainStory: searchResults[selectedIndex].mainStory,
                      mainStoryWithExtras:
                        searchResults[selectedIndex].mainStoryWithExtras,
                      completionist: searchResults[selectedIndex].completionist,
                    },
                  }}
                  className="flex justify-center"
                >
                  <Button className="h-[3rem] max-w-md min-w-[13rem] bg-blue-700 px-6 font-bold text-white hover:bg-blue-800">
                    <span className="truncate">Continue in Creation Tool</span>
                  </Button>
                </Link>
              )}
            </div>
          )}
        </DialogPrimitive.Content>
      </DialogPortal>
    </Dialog>
  );
};
