import { parse } from "csv-parse";
import { SearchGame } from "../howlongtobeat/howLongToBeat";
import type { Pool } from "pg";
import * as backlogEntryService from "~/server/services/backlogEntryService";

export interface CSVRecord {
  [key: string]: unknown;
}

export interface ColumnConfig {
  titleColumn: string;
  genreColumn: string;
  platformColumn: string;
  statusColumn: string;
}

export interface BacklogEntryInput {
  title: string;
  genre: string;
  platform: string;
  status: string;
  owned: boolean;
  interest: number;
  releaseDate?: Date;
  imageLink?: string;
  mainTime?: number;
  mainPlusExtraTime?: number;
  completionTime?: number;
  reviewStars?: number;
  review?: string;
  note?: string;
}

export async function parseCSVContent(fileContent: string): Promise<CSVRecord[]> {
  return new Promise((resolve, reject) => {
    const records: CSVRecord[] = [];

    const parser = parse(fileContent, {
      columns: false,
      skip_empty_lines: true,
    });

    parser.on("readable", function () {
      let record;
      while ((record = parser.read()) !== null) {
        records.push(record);
      }
    });

    parser.on("error", function (err) {
      reject(new Error(`CSV parsing error: ${err.message}`));
    });

    parser.on("end", function () {
      resolve(transformRecords(records));
    });
  });
}

function transformRecords(records: CSVRecord[]): CSVRecord[] {
  const keys = [
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z",
  ];

  return records.map((row: any) => {
    const transformedRow: CSVRecord = {};

    row.forEach((value: unknown, index: number) => {
      const key = keys[index];
      if (key !== undefined) {
        transformedRow[key] = value;
      }
    });

    return transformedRow;
  });
}

export async function importBacklogEntriesFromCSV(
  pool: Pool,
  userId: number,
  records: CSVRecord[],
  config: ColumnConfig
): Promise<{
  success: number;
  failed: number;
  errors: Array<{ title: string; error: string }>;
}> {
  const results = {
    success: 0,
    failed: 0,
    errors: [] as Array<{ title: string; error: string }>,
  };

  for (const record of records) {
    try {
      const title = String(record[config.titleColumn] || "").trim();

      if (!title) {
        results.failed++;
        results.errors.push({
          title: "Unknown",
          error: `Title (column ${config.titleColumn}) is required`,
        });
        continue;
      }

      // Search for the game in howLongToBeat to get additional data
      let gameData = null;
      try {
        const searchResults = await SearchGame(title);
        if (searchResults && searchResults.length > 0) {
          gameData = searchResults[0];
        }
      } catch (searchError) {
        console.warn(`Could not find game "${title}" in howLongToBeat:`, searchError);
      }

      // TODO status cannot be imported for now, because waiting on new changes on main
      const entryData: BacklogEntryInput = {
        title,
        genre: String(record[config.genreColumn] || "Unknown"),
        platform: String(record[config.platformColumn] || "Unknown"),
        status: 'Not Started',
        owned: true,
        interest: 5,
        imageLink: gameData?.imageUrl || undefined,
        mainTime: gameData?.mainStory || undefined,
        mainPlusExtraTime: gameData?.mainStoryWithExtras || undefined,
        completionTime: gameData?.completionist || undefined,
      };

      await backlogEntryService.createBacklogEntry(
        pool,
        userId,
        entryData.title,
        entryData.genre,
        entryData.platform,
        entryData.status,
        entryData.owned,
        entryData.interest,
        entryData.releaseDate,
        entryData.imageLink,
        entryData.mainTime,
        entryData.mainPlusExtraTime,
        entryData.completionTime,
        entryData.reviewStars,
        entryData.review,
        entryData.note
      );

      results.success++;
    } catch (error) {
      results.failed++;
      const title = String(record[config.titleColumn] || "Unknown");
      results.errors.push({
        title,
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }

  return results;
}