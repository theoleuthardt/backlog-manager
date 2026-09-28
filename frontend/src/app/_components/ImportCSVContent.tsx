"use client";
import { memo, useCallback, useRef, useState } from "react";
import Image from "next/image";
import { AlertTriangle, ChevronDown, ChevronUp, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "shadcn_components/ui/button";
import { Input } from "shadcn_components/ui/input";
import { CoverPickerDialog } from "components/CoverPickerDialog";
import { FieldDiffList } from "components/FieldDiffList";
import { GameImage } from "components/GameImage";
import { WrongGameDialog } from "components/WrongGameDialog";
import {
  useCsvHeaders,
  useCsvPreviewStream,
  useCsvSubmitStream,
} from "~/hooks/useCsvImport";
import { DEFAULT_STATUSES } from "~/lib/api/backlog";
import type { GameSearchResult } from "~/lib/api/games";
import type { ColumnConfig, CsvPreviewItem } from "~/lib/api/csv";

const FILLED_BUTTON =
  "border-2 border-white bg-white text-black hover:bg-gray-900 hover:text-white";

const DEFAULT_CONFIG: ColumnConfig = {
  titleColumn: "A",
  genreColumn: "B",
  platformColumn: "C",
  statusColumn: "D",
  playtimeColumn: null,
  ratingColumn: null,
  completedAtColumn: null,
  noteColumns: [],
  reviewColumns: [],
};

const NONE_VALUE = "__none__";

function columnLabel(letter: string, headers: Record<string, string>): string {
  const header = headers[letter];
  return header ? `${letter}: ${header}` : letter;
}

function ColumnSelect({
  label,
  headers,
  value,
  onChange,
  allowNone,
}: {
  label: string;
  headers: Record<string, string>;
  value: string | null;
  onChange: (value: string | null) => void;
  allowNone?: boolean;
}) {
  const letters = Object.keys(headers);
  return (
    <div className="flex flex-col gap-2">
      <label className="text-sm font-medium text-white">{label}</label>
      <select
        value={value ?? NONE_VALUE}
        onChange={(e) =>
          onChange(e.target.value === NONE_VALUE ? null : e.target.value)
        }
        className="rounded border-2 border-white bg-black px-3 py-2 text-white"
      >
        {allowNone && <option value={NONE_VALUE}>-- none --</option>}
        {letters.map((letter) => (
          <option key={letter} value={letter}>
            {columnLabel(letter, headers)}
          </option>
        ))}
      </select>
    </div>
  );
}

function ColumnCheckboxes({
  label,
  headers,
  selected,
  onChange,
}: {
  label: string;
  headers: Record<string, string>;
  selected: string[];
  onChange: (selected: string[]) => void;
}) {
  return (
    <div className="mt-4">
      <p className="mb-2 text-sm font-medium text-white">{label}</p>
      <div className="flex flex-wrap gap-3">
        {Object.keys(headers).map((letter) => (
          <label
            key={letter}
            className="flex items-center gap-1.5 text-sm text-white/80"
          >
            <input
              type="checkbox"
              checked={selected.includes(letter)}
              onChange={(e) =>
                onChange(
                  e.target.checked
                    ? [...selected, letter]
                    : selected.filter((c) => c !== letter),
                )
              }
            />
            {columnLabel(letter, headers)}
          </label>
        ))}
      </div>
    </div>
  );
}

function DuplicateWarning({ item }: { item: CsvPreviewItem }) {
  const [expanded, setExpanded] = useState(false);
  if (item.duplicates.length === 0) return null;

  return (
    <div className="mt-1 rounded border border-yellow-500/50 bg-yellow-500/10 p-2 text-xs">
      <button
        type="button"
        onClick={() => setExpanded(!expanded)}
        className="flex w-full items-center gap-1.5 text-left font-semibold text-yellow-400"
      >
        <AlertTriangle className="h-3.5 w-3.5 shrink-0" />
        Already in your backlog ({item.duplicates.length})
        {expanded ? (
          <ChevronUp className="ml-auto h-3.5 w-3.5" />
        ) : (
          <ChevronDown className="ml-auto h-3.5 w-3.5" />
        )}
      </button>
      {expanded && (
        <div className="mt-2 space-y-2">
          {item.duplicates.map((duplicate) => (
            <div
              key={duplicate.backlogEntryId}
              className="border-t border-yellow-500/30 pt-2"
            >
              <p className="font-medium text-white">{duplicate.title}</p>
              <div className="mt-1">
                <FieldDiffList diffs={duplicate.diffs} />
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

/**
 * Renders one preview row. Memoized with stable `onChange`/`onRemove`
 * (both take `rowIndex` and are defined once at the parent, not per row)
 * so editing one row's fields doesn't re-render the other ~1000+ rows in
 * a full MYY-Master-List-sized import - without this, every keystroke
 * would re-render the entire table.
 */
const PreviewRow = memo(function PreviewRow({
  item,
  onChange,
  onRemove,
  onWrongGame,
  onPickCover,
}: {
  item: CsvPreviewItem;
  onChange: (rowIndex: number, updates: Partial<CsvPreviewItem>) => void;
  onRemove: (rowIndex: number) => void;
  onWrongGame: (rowIndex: number) => void;
  onPickCover: (rowIndex: number) => void;
}) {
  const statusOptions = DEFAULT_STATUSES.includes(
    item.status as (typeof DEFAULT_STATUSES)[number],
  )
    ? DEFAULT_STATUSES
    : [...DEFAULT_STATUSES, item.status];

  return (
    <div className="border-b border-white/10 p-3 last:border-b-0">
      <div className="flex items-start gap-3">
        <button
          type="button"
          onClick={() => onPickCover(item.rowIndex)}
          aria-label={`Choose cover for ${item.title}`}
          title="Choose cover"
          className="shrink-0 overflow-hidden rounded border border-transparent hover:border-white"
        >
          <GameImage
            src={item.imageLink ?? ""}
            alt={item.title}
            width={48}
            height={64}
          />
        </button>
        <div className="grid flex-1 grid-cols-2 gap-2 sm:grid-cols-4">
          <Input
            value={item.title}
            onChange={(e) => onChange(item.rowIndex, { title: e.target.value })}
            aria-label="Title"
            placeholder="Title"
            className="col-span-2 sm:col-span-1"
          />
          <Input
            value={item.genre}
            onChange={(e) => onChange(item.rowIndex, { genre: e.target.value })}
            aria-label="Genre"
            placeholder="Genre"
          />
          <Input
            value={item.platform.join(", ")}
            onChange={(e) =>
              onChange(item.rowIndex, {
                platform: e.target.value
                  .split(",")
                  .map((p) => p.trim())
                  .filter(Boolean),
              })
            }
            aria-label="Platform"
            placeholder="Platform"
          />
          <select
            value={item.status}
            onChange={(e) =>
              onChange(item.rowIndex, { status: e.target.value })
            }
            aria-label="Status"
            className="rounded border-2 border-white bg-black px-3 py-2 text-sm text-white"
          >
            {statusOptions.map((status) => (
              <option key={status} value={status}>
                {status}
              </option>
            ))}
          </select>
        </div>
        <label className="flex items-center gap-1.5 text-xs whitespace-nowrap text-white/70">
          <input
            type="checkbox"
            checked={item.owned}
            onChange={(e) =>
              onChange(item.rowIndex, { owned: e.target.checked })
            }
          />
          Owned
        </label>
        <Button
          variant="outline"
          size="sm"
          className="whitespace-nowrap"
          onClick={() => onWrongGame(item.rowIndex)}
        >
          Wrong Game
        </Button>
        <button
          type="button"
          aria-label={`Remove ${item.title} from the preview`}
          title={`Remove ${item.title} from the preview`}
          onClick={() => onRemove(item.rowIndex)}
          className="text-gray-400 transition-colors hover:text-red-500"
        >
          <Trash2 className="h-4 w-4" />
        </button>
      </div>
      <div className="mt-1 flex flex-wrap gap-3 pl-[3.75rem] text-xs text-gray-400">
        {item.playtime !== undefined && <span>{item.playtime}h played</span>}
        {item.reviewStars !== undefined && (
          <span>Rating: {item.reviewStars}/10</span>
        )}
        {item.completedAt && (
          <span>
            Completed:{" "}
            {new Date(item.completedAt).toLocaleDateString(undefined, {
              year: "numeric",
              month: "long",
            })}
          </span>
        )}
        {item.note && <span>Note: {item.note}</span>}
        {item.review && <span>Review: {item.review}</span>}
        {!item.matched && (
          <span className="text-yellow-400">
            No match found - will import without cover/times
          </span>
        )}
      </div>
      <DuplicateWarning item={item} />
    </div>
  );
});

export const ImportCSVContent = () => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [content, setContent] = useState<string | null>(null);
  const [headers, setHeaders] = useState<Record<string, string> | null>(null);
  const [config, setConfig] = useState<ColumnConfig>(DEFAULT_CONFIG);
  const [preview, setPreview] = useState<CsvPreviewItem[] | null>(null);
  const [wrongGameRowIndex, setWrongGameRowIndex] = useState<number | null>(
    null,
  );
  const [coverPickerRowIndex, setCoverPickerRowIndex] = useState<number | null>(
    null,
  );

  const csvHeaders = useCsvHeaders();
  const csvPreview = useCsvPreviewStream();
  const csvSubmit = useCsvSubmitStream();

  const isBusy =
    csvHeaders.isLoading || csvPreview.isRunning || csvSubmit.isRunning;

  const handleButtonClick = () => fileInputRef.current?.click();

  const handleFileChange = async (
    event: React.ChangeEvent<HTMLInputElement>,
  ) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;

    setPreview(null);
    setHeaders(null);
    try {
      const fileContent = await file.text();
      setContent(fileContent);
      const fetchedHeaders = await csvHeaders.run(fileContent);
      setHeaders(fetchedHeaders);
      setConfig(DEFAULT_CONFIG);
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Failed to read CSV file",
      );
    }
  };

  const handlePreview = async () => {
    if (!content) return;
    try {
      const items = await csvPreview.run(content, config);
      setPreview(items);
      if (items.length === 0) {
        toast.info("No rows with a title found to preview");
      }
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Failed to preview CSV import",
      );
    }
  };

  const handleSubmit = async () => {
    if (!preview || preview.length === 0) return;
    try {
      const created = await csvSubmit.run(
        preview.map((item) => ({
          title: item.title,
          genre: item.genre,
          platform: item.platform,
          status: item.status,
          owned: item.owned,
          playtime: item.playtime,
          reviewStars: item.reviewStars,
          note: item.note,
          review: item.review,
          completedAt: item.completedAt,
          imageLink: item.imageLink,
          description: item.description,
          mainTime: item.mainTime,
          mainPlusExtraTime: item.mainPlusExtraTime,
          completionTime: item.completionTime,
        })),
      );
      toast.success(
        `Imported ${created.length} backlog entr${created.length === 1 ? "y" : "ies"}`,
      );
      setPreview(null);
      setContent(null);
      setHeaders(null);
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Failed to submit CSV import",
      );
    }
  };

  const updateRow = useCallback(
    (rowIndex: number, updates: Partial<CsvPreviewItem>) => {
      setPreview((current) =>
        current
          ? current.map((item) =>
              item.rowIndex === rowIndex ? { ...item, ...updates } : item,
            )
          : current,
      );
    },
    [],
  );

  const removeRow = useCallback((rowIndex: number) => {
    setPreview((current) =>
      current ? current.filter((item) => item.rowIndex !== rowIndex) : current,
    );
  }, []);

  const handleGameSelected = (result: GameSearchResult) => {
    if (wrongGameRowIndex === null) return;
    updateRow(wrongGameRowIndex, {
      title: result.title,
      ...(result.genres.length > 0 ? { genre: result.genres.join(", ") } : {}),
      imageLink: result.imageUrl,
      description: result.description,
      mainTime: result.mainStory,
      mainPlusExtraTime: result.mainStoryWithExtras,
      completionTime: result.completionist,
      matched: true,
    });
    setWrongGameRowIndex(null);
  };

  const wrongGameItem = preview?.find(
    (item) => item.rowIndex === wrongGameRowIndex,
  );

  const handleCoverSelected = (url: string) => {
    if (coverPickerRowIndex === null) return;
    updateRow(coverPickerRowIndex, { imageLink: url, matched: true });
    setCoverPickerRowIndex(null);
  };

  const coverPickerItem = preview?.find(
    (item) => item.rowIndex === coverPickerRowIndex,
  );

  return (
    <div className="flex flex-col items-center gap-8 py-12">
      <div className="flex flex-col items-center gap-4">
        <Image
          src="/csv_import.png"
          alt="import CSV"
          width={64}
          height={64}
          className="themed-icon"
        />
        <h1 className="text-3xl font-bold">Import Backlog from CSV</h1>
        <p className="max-w-md text-center text-gray-400">
          Select a CSV file, pick which columns map to which field, then preview
          what would be imported before anything is written to your backlog.
        </p>
      </div>

      <Button
        className={FILLED_BUTTON}
        onClick={handleButtonClick}
        disabled={isBusy}
        size="lg"
      >
        Select CSV File
      </Button>
      <input
        ref={fileInputRef}
        type="file"
        accept=".csv"
        className="hidden"
        onChange={(e) => void handleFileChange(e)}
      />

      {headers && (
        <div className="w-full max-w-3xl rounded-lg border-2 border-white bg-black p-6">
          <h2 className="mb-4 text-xl font-semibold">Column mapping</h2>
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
            <ColumnSelect
              label="Title"
              headers={headers}
              value={config.titleColumn}
              onChange={(v) => setConfig({ ...config, titleColumn: v ?? "A" })}
            />
            <ColumnSelect
              label="Genre"
              headers={headers}
              value={config.genreColumn}
              onChange={(v) => setConfig({ ...config, genreColumn: v ?? "B" })}
            />
            <ColumnSelect
              label="Platform"
              headers={headers}
              value={config.platformColumn}
              onChange={(v) =>
                setConfig({ ...config, platformColumn: v ?? "C" })
              }
            />
            <ColumnSelect
              label="Status"
              headers={headers}
              value={config.statusColumn}
              onChange={(v) => setConfig({ ...config, statusColumn: v ?? "D" })}
            />
            <ColumnSelect
              label="Playtime (optional)"
              headers={headers}
              value={config.playtimeColumn}
              onChange={(v) => setConfig({ ...config, playtimeColumn: v })}
              allowNone
            />
            <ColumnSelect
              label="Rating (optional)"
              headers={headers}
              value={config.ratingColumn}
              onChange={(v) => setConfig({ ...config, ratingColumn: v })}
              allowNone
            />
            <ColumnSelect
              label="Completed date (optional)"
              headers={headers}
              value={config.completedAtColumn}
              onChange={(v) => setConfig({ ...config, completedAtColumn: v })}
              allowNone
            />
          </div>

          <ColumnCheckboxes
            label="Review columns (optional, merged into the review text - e.g. 'Reason Finished'/'Reason Dropped')"
            headers={headers}
            selected={config.reviewColumns}
            onChange={(reviewColumns) =>
              setConfig({ ...config, reviewColumns })
            }
          />

          <ColumnCheckboxes
            label="Note columns (optional, merged as 'Header: Value' so short yes/no-style columns keep their context)"
            headers={headers}
            selected={config.noteColumns}
            onChange={(noteColumns) => setConfig({ ...config, noteColumns })}
          />

          <Button
            className={`${FILLED_BUTTON} mt-6`}
            onClick={() => void handlePreview()}
            disabled={isBusy}
          >
            {csvPreview.isRunning
              ? csvPreview.progress
                ? `Loading ${csvPreview.progress.processed}/${csvPreview.progress.total}...`
                : "Loading preview..."
              : "Preview import"}
          </Button>
        </div>
      )}

      {preview && (
        <div className="w-full max-w-3xl rounded-lg border-2 border-white bg-black p-6">
          <div className="mb-4 flex items-center justify-between gap-4">
            <h2 className="text-xl font-semibold">
              Preview ({preview.length} entr{preview.length === 1 ? "y" : "ies"}
              )
            </h2>
            <Button
              className={FILLED_BUTTON}
              onClick={() => void handleSubmit()}
              disabled={isBusy || preview.length === 0}
            >
              {csvSubmit.isRunning
                ? csvSubmit.progress
                  ? `Importing ${csvSubmit.progress.processed}/${csvSubmit.progress.total}...`
                  : "Importing..."
                : "Submit import"}
            </Button>
          </div>
          <div className="max-h-[32rem] overflow-y-auto rounded-lg border border-white/20">
            {preview.map((item) => (
              <PreviewRow
                key={item.rowIndex}
                item={item}
                onChange={updateRow}
                onRemove={removeRow}
                onWrongGame={setWrongGameRowIndex}
                onPickCover={setCoverPickerRowIndex}
              />
            ))}
          </div>
        </div>
      )}

      <WrongGameDialog
        open={wrongGameRowIndex !== null}
        onOpenChange={(open) => {
          if (!open) setWrongGameRowIndex(null);
        }}
        initialQuery={wrongGameItem?.title}
        onSelect={handleGameSelected}
      />

      <CoverPickerDialog
        open={coverPickerRowIndex !== null}
        onOpenChange={(open) => {
          if (!open) setCoverPickerRowIndex(null);
        }}
        initialQuery={coverPickerItem?.title ?? ""}
        onSelect={handleCoverSelected}
      />
    </div>
  );
};
