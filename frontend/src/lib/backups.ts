const KIND_LABELS: Record<string, string> = {
  auto: "Automatic",
  manual: "Manual",
  "pre-restore": "Before a restore",
  "pre-delete": "Before deleting all games",
  "pre-import": "Before a CSV import",
};

export const MAX_BACKUP_NAME_LENGTH = 60;

export function backupKindLabel(kind: string): string {
  return KIND_LABELS[kind] ?? kind;
}

function plural(count: number, singular: string, pluralForm: string): string {
  return `${count} ${count === 1 ? singular : pluralForm}`;
}

export function backupContentSummary(backup: {
  entryCount: number;
  categoryCount: number;
}): string {
  return `${plural(backup.entryCount, "game", "games")}, ${plural(
    backup.categoryCount,
    "category",
    "categories",
  )}`;
}

export function backupTitle(backup: {
  name: string | null;
  kind: string;
}): string {
  return backup.name ?? backupKindLabel(backup.kind);
}

export function normalizeBackupName(input: string): string | null {
  const trimmed = input.trim();
  return trimmed === "" ? null : trimmed;
}
