import { parse } from "csv-parse";
import { SearchGame } from "../integrations/howlongtobeat/howLongToBeat";
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

export interface MissingGame {
  title: string;
  genre: string;
  platform: string;
  status: string;
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
  missingGames: MissingGame[];
}> {
  const results = {
    success: 0,
    failed: 0,
    errors: [] as Array<{ title: string; error: string }>,
    missingGames: [] as MissingGame[],
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
      let foundInHLTB = false;
      try {
        const searchResults = await SearchGame(title);
        if (searchResults && searchResults.length > 0) {
          gameData = searchResults[0];
          foundInHLTB = true;
        }
      } catch (searchError) {
        console.warn(`Could not find game "${title}" in howLongToBeat:`, searchError);
      }

      // If not found in HLTB, add to missing games list
      if (!foundInHLTB) {
        results.missingGames.push({
          title,
          genre: String(record[config.genreColumn] || "Unknown"),
          platform: String(record[config.platformColumn] || "Unknown"),
          status: String(record[config.statusColumn] || "Not Started"),
        });
        continue;
      }

      //TODO Status is currently buggy because for now there are only enum states. Will be fixed in https://github.com/theoleuthardt/backlog-manager/issues/64#issue-3648683095
      const entryParams = {
        userId,
        title,
        genre: String(record[config.genreColumn] || "Unknown"),
        platform: String(record[config.platformColumn] || "Unknown"),
        status: String(record[config.statusColumn] || "Not Started"),
        owned: true,
        interest: 5,
        imageLink: gameData?.imageUrl,
        mainTime: gameData?.mainStory,
        mainPlusExtraTime: gameData?.mainStoryWithExtras,
        completionTime: gameData?.completionist,
      };

      await backlogEntryService.createBacklogEntry(pool, entryParams);

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