import { describe, expect, it } from "vitest";
import {
  backupContentSummary,
  backupKindLabel,
  backupTitle,
  MAX_BACKUP_NAME_LENGTH,
  normalizeBackupName,
} from "~/lib/backups";

describe("backupKindLabel", () => {
  it("names every backup kind the backend creates", () => {
    expect(backupKindLabel("auto")).toBe("Automatic");
    expect(backupKindLabel("manual")).toBe("Manual");
    expect(backupKindLabel("pre-restore")).toBe("Before a restore");
    expect(backupKindLabel("pre-delete")).toBe("Before deleting all games");
    expect(backupKindLabel("pre-import")).toBe("Before a CSV import");
  });

  it("falls back to the raw kind for one it does not know", () => {
    expect(backupKindLabel("something-new")).toBe("something-new");
  });
});

describe("backupContentSummary", () => {
  it("counts games and categories", () => {
    expect(backupContentSummary({ entryCount: 12, categoryCount: 3 })).toBe(
      "12 games, 3 categories",
    );
  });

  it("uses the singular for exactly one", () => {
    expect(backupContentSummary({ entryCount: 1, categoryCount: 1 })).toBe(
      "1 game, 1 category",
    );
  });

  it("handles an empty backlog", () => {
    expect(backupContentSummary({ entryCount: 0, categoryCount: 0 })).toBe(
      "0 games, 0 categories",
    );
  });
});

describe("backupTitle", () => {
  it("prefers the name the user gave", () => {
    expect(backupTitle({ name: "Before the sale", kind: "manual" })).toBe(
      "Before the sale",
    );
  });

  it("falls back to the kind label without a name", () => {
    expect(backupTitle({ name: null, kind: "auto" })).toBe("Automatic");
  });
});

describe("normalizeBackupName", () => {
  it("trims surrounding whitespace", () => {
    expect(normalizeBackupName("  Pre-sale  ")).toBe("Pre-sale");
  });

  it("turns a blank name into null so the label is cleared", () => {
    expect(normalizeBackupName("")).toBeNull();
    expect(normalizeBackupName("   ")).toBeNull();
  });

  it("matches the backend's length limit", () => {
    expect(MAX_BACKUP_NAME_LENGTH).toBe(60);
  });
});
