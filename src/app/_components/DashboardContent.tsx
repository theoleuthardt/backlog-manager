"use client";
import React, { useState, useMemo } from "react";
import { BacklogEntry, SearchBar } from "components";
import {
  ToggleGroup,
  ToggleGroupItem,
} from "shadcn_components/ui/toggle-group";
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "shadcn_components/ui/dropdown-menu";
import { Checkbox } from "shadcn_components/ui/checkbox";
import { Slider } from "shadcn_components/ui/slider";
import { Label } from "shadcn_components/ui/label";
import Image from "next/image";
import type { DashboardContentProps } from "~/app/types";

export const DashboardContent = ({ initialData }: DashboardContentProps) => {
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedPlatforms, setSelectedPlatforms] = useState<string[]>([]);
  const [selectedGenres, setSelectedGenres] = useState<string[]>([]);
  const [selectedStatuses, setSelectedStatuses] = useState<string[]>([]);
  const [ownedOnly, setOwnedOnly] = useState(false);
  const [interestRange, setInterestRange] = useState<[number, number]>([1, 10]);
  const [reviewStarsRange, setReviewStarsRange] = useState<[number, number]>([
    1, 5,
  ]);
  const [mainTimeRange, setMainTimeRange] = useState<[number, number]>([
    0, 500,
  ]);
  const [mainExtraTimeRange, setMainExtraTimeRange] = useState<
    [number, number]
  >([0, 500]);
  const [completionistTimeRange, setCompletionistTimeRange] = useState<
    [number, number]
  >([0, 500]);
  const [isLeftBarOpen, setIsLeftBarOpen] = useState(false);

  const maxPlaytime = useMemo(() => {
    const max = Math.max(...initialData.map((entry) => entry.playtime ?? 0), 0);
    // Round to even number
    return max % 2 === 0 ? max : max + 1;
  }, [initialData]);

  const [playtimeRange, setPlaytimeRange] = useState<[number, number]>([
    0,
    maxPlaytime,
  ]);

  const allPlatforms = useMemo(() => {
    const platforms = new Set<string>();
    initialData.forEach((entry) => {
      entry.platform?.forEach((p) => platforms.add(p));
    });
    return Array.from(platforms).sort();
  }, [initialData]);

  const allGenres = useMemo(() => {
    const genres = new Set<string>();
    initialData.forEach((entry) => {
      entry.genre?.forEach((g) => genres.add(g));
    });
    return Array.from(genres).sort();
  }, [initialData]);

  const statusOptions = [
    "Not Started",
    "In Progress",
    "Completed",
    "On Hold",
    "Dropped",
  ];

  const filteredData = useMemo(() => {
    return initialData.filter((entry) => {
      if (
        searchQuery.trim() &&
        !entry.title.toLowerCase().includes(searchQuery.toLowerCase())
      ) {
        return false;
      }

      if (selectedPlatforms.length > 0) {
        const hasMatchingPlatform = entry.platform?.some((p) =>
          selectedPlatforms.includes(p),
        );
        if (!hasMatchingPlatform) return false;
      }

      if (selectedGenres.length > 0) {
        const hasMatchingGenre = entry.genre?.some((g) =>
          selectedGenres.includes(g),
        );
        if (!hasMatchingGenre) return false;
      }

      if (selectedStatuses.length > 0 && entry.status) {
        if (!selectedStatuses.includes(entry.status)) return false;
      }

      if (ownedOnly && !entry.owned) {
        return false;
      }

      if (entry.interest !== undefined) {
        if (
          entry.interest < interestRange[0] ||
          entry.interest > interestRange[1]
        ) {
          return false;
        }
      }

      if (entry.reviewStars !== undefined) {
        if (
          entry.reviewStars < reviewStarsRange[0] ||
          entry.reviewStars > reviewStarsRange[1]
        ) {
          return false;
        }
      }

      if (entry.playtime !== undefined) {
        if (
          entry.playtime < playtimeRange[0] ||
          entry.playtime > playtimeRange[1]
        ) {
          return false;
        }
      }

      if (
        entry.mainTime !== undefined &&
        (entry.mainTime < mainTimeRange[0] || entry.mainTime > mainTimeRange[1])
      ) {
        return false;
      }

      if (
        entry.mainPlusExtraTime !== undefined &&
        (entry.mainPlusExtraTime < mainExtraTimeRange[0] ||
          entry.mainPlusExtraTime > mainExtraTimeRange[1])
      ) {
        return false;
      }

      if (
        entry.completionTime !== undefined &&
        (entry.completionTime < completionistTimeRange[0] ||
          entry.completionTime > completionistTimeRange[1])
      ) {
        return false;
      }

      return true;
    });
  }, [
    initialData,
    searchQuery,
    selectedPlatforms,
    selectedGenres,
    selectedStatuses,
    ownedOnly,
    interestRange,
    reviewStarsRange,
    playtimeRange,
    mainTimeRange,
    mainExtraTimeRange,
    completionistTimeRange,
  ]);

  return (
    <div id="upperSection" className="flex min-h-30 gap-8 p-4">
      <div className="ml-4 flex flex-col">
        <button
          onClick={() => setIsLeftBarOpen(!isLeftBarOpen)}
          className={`group flex h-10 items-center justify-center self-center rounded-md border-2 border-white bg-black text-2xl font-bold text-white transition-all duration-300 ease-in-out hover:bg-white ${
            isLeftBarOpen ? "w-44" : "w-10"
          }`}
          aria-label={isLeftBarOpen ? "Close sidebar" : "Open sidebar"}
        >
          <Image
            src={isLeftBarOpen ? "/chevron-left.png" : "/chevron-right.png"}
            alt={isLeftBarOpen ? "Collapse" : "Expand"}
            className="h-6 w-6 transition-all duration-300 group-hover:invert"
            width={60}
            height={60}
          />
        </button>
        <div
          id="leftBar"
          className={`h-[40rem] flex-shrink-0 overflow-hidden p-4 transition-all duration-300 ease-in-out ${
            isLeftBarOpen ? "w-60 opacity-100" : "w-0 p-0 opacity-0"
          }`}
        >
          <div
            id="filterOptions"
            className="mb-4 h-full space-y-4 overflow-y-auto p-4"
          >
            <div className="space-y-2">
              <SearchBar
                useIcon={true}
                onInput={(e: React.ChangeEvent<HTMLInputElement>) => {
                  setSearchQuery(e.target.value);
                }}
              />
              <Label className="text-sm font-medium text-white">Platform</Label>
              <ToggleGroup
                type="multiple"
                value={selectedPlatforms}
                onValueChange={setSelectedPlatforms}
                className="flex flex-wrap justify-start gap-1"
              >
                {allPlatforms.map((platform) => (
                  <ToggleGroupItem
                    key={platform}
                    value={platform}
                    className="h-8 px-2 text-xs data-[state=on]:bg-blue-700 data-[state=on]:text-white"
                  >
                    {platform}
                  </ToggleGroupItem>
                ))}
              </ToggleGroup>
            </div>

            <div className="space-y-2">
              <Label className="text-sm font-medium text-white">Genre</Label>
              <DropdownMenu>
                <DropdownMenuTrigger className="w-full rounded-md border border-white bg-black px-3 py-2 text-sm text-white hover:bg-white hover:text-black">
                  {selectedGenres.length > 0
                    ? `${selectedGenres.length} selected`
                    : "Select genres"}
                </DropdownMenuTrigger>
                <DropdownMenuContent className="max-h-60 w-56 overflow-y-auto border-white bg-black">
                  {allGenres.map((genre) => (
                    <DropdownMenuCheckboxItem
                      key={genre}
                      checked={selectedGenres.includes(genre)}
                      onCheckedChange={(checked) => {
                        setSelectedGenres(
                          checked
                            ? [...selectedGenres, genre]
                            : selectedGenres.filter((g) => g !== genre),
                        );
                      }}
                      className="text-white hover:bg-white hover:text-black"
                    >
                      {genre}
                    </DropdownMenuCheckboxItem>
                  ))}
                </DropdownMenuContent>
              </DropdownMenu>
            </div>

            <div className="space-y-2">
              <Label className="text-sm font-medium text-white">Status</Label>
              <DropdownMenu>
                <DropdownMenuTrigger className="w-full rounded-md border border-white bg-black px-3 py-2 text-sm text-white hover:bg-white hover:text-black">
                  {selectedStatuses.length > 0
                    ? `${selectedStatuses.length} selected`
                    : "Select status"}
                </DropdownMenuTrigger>
                <DropdownMenuContent className="w-56 border-white bg-black">
                  {statusOptions.map((status) => (
                    <DropdownMenuCheckboxItem
                      key={status}
                      checked={selectedStatuses.includes(status)}
                      onCheckedChange={(checked) => {
                        setSelectedStatuses(
                          checked
                            ? [...selectedStatuses, status]
                            : selectedStatuses.filter((s) => s !== status),
                        );
                      }}
                      className="text-white hover:bg-white hover:text-black"
                    >
                      {status}
                    </DropdownMenuCheckboxItem>
                  ))}
                </DropdownMenuContent>
              </DropdownMenu>
            </div>

            <div className="flex items-center space-x-2">
              <Checkbox
                id="owned"
                checked={ownedOnly}
                onCheckedChange={(checked) => setOwnedOnly(checked as boolean)}
                className="border-white data-[state=checked]:bg-blue-700"
              />
              <Label
                htmlFor="owned"
                className="cursor-pointer text-sm font-medium text-white"
              >
                Owned only
              </Label>
            </div>

            <div className="space-y-2">
              <Label className="text-sm font-medium text-white">
                Interest: {interestRange[0]} - {interestRange[1]}
              </Label>
              <Slider
                min={1}
                max={10}
                step={1}
                value={interestRange}
                onValueChange={(value) =>
                  setInterestRange(value as [number, number])
                }
                className="invert"
              />
            </div>

            <div className="space-y-2">
              <Label className="text-sm font-medium text-white">
                Review Stars: {reviewStarsRange[0]} - {reviewStarsRange[1]}
              </Label>
              <Slider
                min={1}
                max={5}
                step={1}
                value={reviewStarsRange}
                onValueChange={(value) =>
                  setReviewStarsRange(value as [number, number])
                }
                className="invert"
              />
            </div>

            <div className="space-y-2">
              <Label className="text-sm font-medium text-white">
                Playtime: {playtimeRange[0]}h - {playtimeRange[1]}h
              </Label>
              <Slider
                min={0}
                max={maxPlaytime}
                step={1}
                value={playtimeRange}
                onValueChange={(value) =>
                  setPlaytimeRange(value as [number, number])
                }
                className="invert"
              />
            </div>

            <div className="space-y-2">
              <Label className="text-sm font-medium text-white">
                Main Story: {mainTimeRange[0]}h - {mainTimeRange[1]}h
              </Label>
              <Slider
                min={0}
                max={500}
                step={1}
                value={mainTimeRange}
                onValueChange={(value) =>
                  setMainTimeRange(value as [number, number])
                }
                className="invert"
              />
            </div>

            <div className="space-y-2">
              <Label className="text-sm font-medium text-white">
                Main + Extra: {mainExtraTimeRange[0]}h - {mainExtraTimeRange[1]}
                h
              </Label>
              <Slider
                min={0}
                max={500}
                step={1}
                value={mainExtraTimeRange}
                onValueChange={(value) =>
                  setMainExtraTimeRange(value as [number, number])
                }
                className="invert"
              />
            </div>

            <div className="space-y-2">
              <Label className="text-sm font-medium text-white">
                Completionist: {completionistTimeRange[0]}h -{" "}
                {completionistTimeRange[1]}h
              </Label>
              <Slider
                min={0}
                max={500}
                step={1}
                value={completionistTimeRange}
                onValueChange={(value) =>
                  setCompletionistTimeRange(value as [number, number])
                }
                className="invert"
              />
            </div>
          </div>
        </div>
      </div>
      <div id="entryList" className="mr-4 flex-1 overflow-hidden p-4">
        <div className="grid h-full grid-cols-[repeat(auto-fill,minmax(150px,max-content))] content-start gap-x-2 gap-y-2 overflow-y-auto">
          {filteredData.map((entry) => (
            <BacklogEntry
              key={entry.id}
              title={entry.title}
              playtime={entry.playtime}
              imageLink={entry.imageLink}
              imageAlt={entry.imageAlt}
              genre={entry.genre}
              platform={entry.platform}
              status={entry.status}
              owned={entry.owned}
              interest={entry.interest}
              review={entry.review}
              reviewStars={entry.reviewStars}
              note={entry.note}
              mainTime={entry.mainTime}
              mainPlusExtraTime={entry.mainPlusExtraTime}
              completionTime={entry.completionTime}
            />
          ))}
        </div>
      </div>
    </div>
  );
};
