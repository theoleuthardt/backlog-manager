import { parse } from "csv-parse";
import { SearchGameOnHLTB } from "../integrations/howlongtobeat/howLongToBeat";
import type { Pool } from "pg";
import * as backlogEntryService from "~/server/services/backlogEntryService";

export type CSVRecord = Record<string, unknown>;

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

export async function parseCSVContent(
  fileContent: string,
): Promise<CSVRecord[]> {
  return new Promise((resolve, reject) => {
    const records: unknown[] = [];

    const parser = parse(fileContent, {
      columns: false,
      skip_empty_lines: true,
    });

    parser.on("readable", function () {
      let record: unknown;
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

function safeString(value: unknown, defaultValue = ""): string {
  if (typeof value === "string") return value;
  if (value === undefined || value === null) return defaultValue;
  if (typeof value === "number" || typeof value === "boolean")
    return String(value);
  return defaultValue;
}

function transformRecords(records: unknown[]): CSVRecord[] {
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

  return records.map((row) => {
    const transformedRow: CSVRecord = {};

    if (Array.isArray(row)) {
      row.forEach((value: unknown, index: number) => {
        const key = keys[index];
        if (key !== undefined) {
          transformedRow[key] = value;
        }
      });
    }

    return transformedRow;
  });
}

const importProgressMap = new Map<string, number>();
const importCancelFlagsMap = new Map<string, boolean>();

export function getImportProgress(sessionId: string): number {
  return importProgressMap.get(sessionId) ?? 0;
}

export function setImportProgress(sessionId: string, processed: number) {
  importProgressMap.set(sessionId, processed);
}

export function clearImportProgress(sessionId: string) {
  importProgressMap.delete(sessionId);
  importCancelFlagsMap.delete(sessionId);
}

export function setCancelFlag(sessionId: string, cancelled: boolean) {
  if (cancelled) {
    importCancelFlagsMap.set(sessionId, true);
  } else {
    importCancelFlagsMap.delete(sessionId);
  }
}

export function getCancelFlag(sessionId: string): boolean {
  return importCancelFlagsMap.get(sessionId) ?? false;
}

export function isCancelled(sessionId: string): boolean {
  return getCancelFlag(sessionId);
}

function emitProgress(sessionId: string, processed: number) {
  if (sessionId) {
    setImportProgress(sessionId, processed);
  }
}

export async function importBacklogEntriesFromCSV(
  pool: Pool,
  userId: number,
  records: CSVRecord[],
  config: ColumnConfig,
  sessionId?: string,
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

  let processedCount = 0;

  for (const record of records) {
    if (sessionId && isCancelled(sessionId)) {
      console.log(
        `Import cancelled at record ${processedCount + 1}/${records.length}`,
      );
      break;
    }

    try {
      const title = safeString(record[config.titleColumn], "").trim();

      if (!title) {
        results.failed++;
        results.errors.push({
          title: "Unknown",
          error: `Title (column ${config.titleColumn}) is required`,
        });
        processedCount++;
        if (sessionId) emitProgress(sessionId, processedCount);
        continue;
      }

      let gameData = null;
      let foundInHLTB = false;
      try {
        const searchResults = await SearchGameOnHLTB(title);
        if (searchResults && searchResults.length > 0) {
          gameData = searchResults[0];
          foundInHLTB = true;
        }
      } catch (searchError) {
        console.warn(
          `Could not find game "${title}" in howLongToBeat:`,
          searchError,
        );
      }

      if (!foundInHLTB) {
        results.missingGames.push({
          title,
          genre: safeString(record[config.genreColumn], "Unknown"),
          platform: safeString(record[config.platformColumn], "Unknown"),
          status: safeString(record[config.statusColumn], "Not Started"),
        });
        processedCount++;
        if (sessionId) emitProgress(sessionId, processedCount);
        continue;
      }

      //TODO Status is currently buggy because for now there are only enum states. Will be fixed in https://github.com/theoleuthardt/backlog-manager/issues/64#issue-3648683095
      const entryParams = {
        userId,
        title,
        genre: safeString(record[config.genreColumn], "Unknown"),
        platform: safeString(record[config.platformColumn], "Unknown"),
        status: "Not Started",
        owned: true,
        interest: 5,
        imageLink: gameData?.imageUrl,
        mainTime: gameData?.mainStory,
        mainPlusExtraTime: gameData?.mainStoryWithExtras,
        completionTime: gameData?.completionist,
      };

      try {
        console.log(`📝 Creating backlog entry:`, {
          title,
          genre: entryParams.genre,
          platform: entryParams.platform,
          status: entryParams.status,
        });
        await backlogEntryService.createBacklogEntry(pool, entryParams);
        results.success++;
        processedCount++;
        if (sessionId) emitProgress(sessionId, processedCount);
        console.log(`✓ Created backlog entry: ${title}`);
      } catch (createError) {
        console.error(
          `✗ Failed to create backlog entry for "${title}":`,
          createError,
        );
        throw createError;
      }
    } catch (error) {
      results.failed++;
      results.errors.push({
        title: safeString(record[config.titleColumn], "Unknown"),
        error: error instanceof Error ? error.message : "Unknown error",
      });
      processedCount++;
      if (sessionId) emitProgress(sessionId, processedCount);
    }
  }

  return results;
}
