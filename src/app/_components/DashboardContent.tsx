"use client";
import React, { useState, useMemo } from "react";
import Image from "next/image";
import {
  BacklogEntry,
  CustomDropdownMenu,
  UniSlider,
  SearchBar,
  ImportCSVButton,
  ExportCSVButton,
  EntryCreationDialog,
} from "components";
import { dropdownData } from "~/constants/dropdownData";

interface BacklogEntryData {
  id: number;
  title: string;
  imageLink: string;
  imageAlt?: string;
  genre?: string[];
  platform?: string[];
  status?: string;
  owned?: boolean;
  interest?: number;
  reviewStars?: number;
  review?: string;
  note?: string;
  howLongToBeat?: number[];
}

interface DashboardContentProps {
  initialData: BacklogEntryData[];
}

export const DashboardContent = ({ initialData }: DashboardContentProps) => {
  const [searchQuery, setSearchQuery] = useState("");

  const filteredData = useMemo(() => {
    if (!searchQuery.trim()) {
      return initialData;
    }
    return initialData.filter((entry) =>
      entry.title.toLowerCase().includes(searchQuery.toLowerCase()),
    );
  }, [initialData, searchQuery]);

  return (
    <div id="upperSection" className="flex min-h-30 gap-8 p-4">
      <div id="leftBar" className="h-[23rem] w-48 flex-shrink-0 p-4">
        <SearchBar
          useIcon={true}
          onInput={(e: React.ChangeEvent<HTMLInputElement>) => {
            setSearchQuery(e.target.value);
          }}
        />
        <EntryCreationDialog />
        <ImportCSVButton
          id="csvImportButton"
          className="relative mb-4 h-[2.5rem] w-[10rem] rounded-3xl border-0 bg-blue-700 p-4 font-bold text-white hover:bg-blue-800 hover:text-white"
          disabled={false}
        >
          <Image
            src="/csv_import.png"
            alt="csv_import"
            width={24}
            height={24}
          />
          Import Backlog
        </ImportCSVButton>
        <ExportCSVButton
          id="csvExportButton"
          className="relative mb-4 h-[2.5rem] w-[10rem] rounded-3xl border-0 bg-blue-700 p-4 font-bold text-white hover:bg-blue-800 hover:text-white"
          disabled={false}
        >
          <Image
            src="/csv_export.png"
            alt="csv_export"
            width={24}
            height={24}
          />
          Export Backlog
        </ExportCSVButton>
        <div id="filterOptions" className="mb-4 h-42 p-4 text-center">
          <CustomDropdownMenu items={dropdownData} triggerText={"Dropdown 1"} />
          <CustomDropdownMenu items={dropdownData} triggerText={"Dropdown 2"} />
          <CustomDropdownMenu
            items={dropdownData}
            triggerText={"Dropdown 3"}
            className="mb-10"
          />
          <UniSlider defaultValue={50} step={1} maxvalue={100} />
        </div>
      </div>
      <div id="entryList" className="flex-1 overflow-hidden p-4">
        <div className="grid h-full grid-cols-[repeat(auto-fill,minmax(150px,1fr))] gap-2 overflow-y-auto">
          {filteredData.map((entry) => (
            <BacklogEntry
              key={entry.id}
              title={entry.title}
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
              howLongToBeat={entry.howLongToBeat}
            />
          ))}
        </div>
      </div>
    </div>
  );
};
