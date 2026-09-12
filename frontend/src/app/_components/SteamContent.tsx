"use client";

import { useState } from "react";
import { Loader2, RefreshCw, Search, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { GameImage } from "components/GameImage";
import { Button } from "~/components/ui/button";
import { Spinner } from "~/components/ui/spinner";
import { useAuth } from "~/app/context/AuthContext";
import {
  getSteamWishlistPreview,
  type SteamPreviewItem,
} from "~/lib/api/steam";
import {
  useImportSteamLibraryAppIdsStream,
  useImportSteamWishlistStream,
  useSteamLibraryPreviewStream,
} from "~/hooks/useBacklog";

const FILLED_BUTTON =
  "border-2 border-white bg-white text-black hover:bg-gray-900 hover:text-white";

type PreviewSource = "library" | "wishlist";

function SyncProgressBar({
  processed,
  total,
}: {
  processed: number;
  total: number;
}) {
  const percentage = total > 0 ? Math.round((processed / total) * 100) : 0;
  return (
    <div className="mt-4 flex items-center gap-3">
      <Loader2 className="h-4 w-4 shrink-0 animate-spin" />
      <div className="flex-1">
        <div className="mb-1 text-xs text-gray-400">
          {processed}/{total}
        </div>
        <div className="h-2 w-full overflow-hidden rounded-full bg-white/10">
          <div
            className="h-full bg-white transition-all"
            style={{ width: `${percentage}%` }}
          />
        </div>
      </div>
    </div>
  );
}

function SteamPreviewTable({
  items,
  isImporting,
  progress,
  onImport,
  onRemove,
  importLabel,
}: {
  items: SteamPreviewItem[];
  isImporting: boolean;
  progress: { processed: number; total: number } | null;
  onImport: () => void;
  onRemove: (steamAppId: number) => void;
  importLabel: string;
}) {
  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-4">
        <p className="text-sm text-gray-300">
          {items.length} game{items.length === 1 ? "" : "s"} ready to import
        </p>
        <Button
          className={FILLED_BUTTON}
          onClick={onImport}
          disabled={isImporting || items.length === 0}
        >
          {isImporting ? "Importing..." : importLabel}
        </Button>
      </div>
      {isImporting && progress && (
        <SyncProgressBar processed={progress.processed} total={progress.total} />
      )}
      <div className="max-h-[24rem] overflow-y-auto rounded-lg border-2 border-white/20">
        <table className="w-full">
          <tbody>
            {items.map((item) => (
              <tr
                key={item.steamAppId}
                className="border-b border-white/10 last:border-b-0"
              >
                <td className="w-20 p-2">
                  <GameImage
                    src={item.imageLink ?? ""}
                    alt={item.title}
                    width={60}
                    height={30}
                    className="!rounded-md"
                  />
                </td>
                <td className="p-2 text-sm text-white">{item.title}</td>
                <td className="p-2 text-right text-xs text-gray-400">
                  {item.steamAppId}
                </td>
                <td className="w-10 p-2">
                  <button
                    type="button"
                    aria-label={`Remove ${item.title} from the preview`}
                    title={`Remove ${item.title} from the preview`}
                    onClick={() => onRemove(item.steamAppId)}
                    className="text-gray-400 transition-colors hover:text-red-500"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export function SteamContent() {
  const { user } = useAuth();
  const [activeSource, setActiveSource] = useState<PreviewSource | null>(null);
  const [preview, setPreview] = useState<SteamPreviewItem[] | null>(null);
  const [isFetchingPreview, setIsFetchingPreview] = useState(false);

  const libraryPreview = useSteamLibraryPreviewStream();
  const libraryImport = useImportSteamLibraryAppIdsStream();
  const wishlistImport = useImportSteamWishlistStream();

  const isAnySyncRunning =
    libraryPreview.isRunning ||
    libraryImport.isRunning ||
    wishlistImport.isRunning ||
    isFetchingPreview;

  if (!user) return null;

  const loadLibraryPreview = async () => {
    setActiveSource("library");
    setIsFetchingPreview(true);
    setPreview(null);
    try {
      setPreview(await libraryPreview.run());
    } catch (error) {
      toast.error(
        error instanceof Error
          ? error.message
          : "Failed to load Steam library preview",
      );
    } finally {
      setIsFetchingPreview(false);
    }
  };

  const loadWishlistPreview = async () => {
    setActiveSource("wishlist");
    setIsFetchingPreview(true);
    setPreview(null);
    try {
      setPreview(await getSteamWishlistPreview());
    } catch (error) {
      toast.error(
        error instanceof Error
          ? error.message
          : "Failed to load Steam wishlist",
      );
    } finally {
      setIsFetchingPreview(false);
    }
  };

  const handleLibraryImport = async () => {
    if (!preview) return;
    try {
      const created = await libraryImport.run(
        preview.map((item) => item.steamAppId),
      );
      setPreview(null);
      toast.success(
        created.length > 0
          ? `Imported ${created.length} game${created.length === 1 ? "" : "s"} from your Steam library`
          : "No new games to import, your backlog already has everything",
      );
    } catch (error) {
      toast.error(
        error instanceof Error
          ? error.message
          : "Failed to import Steam library",
      );
    }
  };

  const handleWishlistImport = async () => {
    if (!preview) return;
    try {
      const created = await wishlistImport.run(
        preview.map((item) => ({ appid: item.steamAppId })),
      );
      setPreview(null);
      toast.success(
        created.length > 0
          ? `Imported ${created.length} game${created.length === 1 ? "" : "s"} from your Steam wishlist`
          : "No new games to import, your backlog already has everything",
      );
    } catch (error) {
      toast.error(
        error instanceof Error
          ? error.message
          : "Failed to import Steam wishlist",
      );
    }
  };

  const handleRemoveFromPreview = (steamAppId: number) => {
    setPreview((current) =>
      current ? current.filter((item) => item.steamAppId !== steamAppId) : current,
    );
  };

  const steamLinked = Boolean(user.steamId);

  const renderPreview = () => {
    if (isFetchingPreview && !preview) {
      return (
        <div className="flex items-center gap-2 text-sm text-gray-400">
          <Spinner className="h-4 w-4 text-white" />
          Loading preview...
        </div>
      );
    }
    if (!preview) {
      return (
        <p className="text-sm text-gray-300">
          Nothing loaded yet - trigger a sync above to preview what would be
          imported. Nothing is written until you press Import.
        </p>
      );
    }
    if (preview.length === 0) {
      return (
        <p className="text-sm text-gray-300">
          Nothing new to import - your backlog already has everything.
        </p>
      );
    }
    if (activeSource === "library") {
      return (
        <SteamPreviewTable
          items={preview}
          isImporting={libraryImport.isRunning}
          progress={libraryImport.progress}
          onImport={handleLibraryImport}
          onRemove={handleRemoveFromPreview}
          importLabel="Import library"
        />
      );
    }
    return (
      <SteamPreviewTable
        items={preview}
        isImporting={wishlistImport.isRunning}
        progress={wishlistImport.progress}
        onImport={handleWishlistImport}
        onRemove={handleRemoveFromPreview}
        importLabel="Import wishlist"
      />
    );
  };

  return (
    <div className="flex flex-col gap-8">
      <h1 className="text-3xl font-bold">Steam Sync</h1>

      <div className="rounded-lg border-2 border-white bg-black p-6">
        <h2 className="mb-4 text-xl font-semibold">Library Sync</h2>
        <p className="mb-4 text-sm text-gray-300">
          Loads owned Steam games that aren&apos;t in your backlog yet as a
          preview - press Import below to create the entries.
        </p>
        <Button
          className={FILLED_BUTTON}
          onClick={loadLibraryPreview}
          disabled={!steamLinked || isAnySyncRunning}
        >
          <RefreshCw className="h-4 w-4" />
          {libraryPreview.isRunning
            ? libraryPreview.progress
              ? `Loading ${libraryPreview.progress.processed}/${libraryPreview.progress.total}...`
              : "Loading..."
            : "Load my library"}
        </Button>
        {libraryPreview.isRunning && libraryPreview.progress && (
          <SyncProgressBar
            processed={libraryPreview.progress.processed}
            total={libraryPreview.progress.total}
          />
        )}
      </div>

      <div className="rounded-lg border-2 border-white bg-black p-6">
        <h2 className="mb-4 text-xl font-semibold">Wishlist Sync</h2>
        <p className="mb-4 text-sm text-gray-300">
          Loads your public Steam wishlist as a preview - press Import below to
          create the entries as &quot;Not Owned&quot;.
        </p>
        <Button
          className={FILLED_BUTTON}
          onClick={loadWishlistPreview}
          disabled={!steamLinked || isAnySyncRunning}
        >
          {isFetchingPreview && activeSource === "wishlist" ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Search className="h-4 w-4" />
          )}
          Load my wishlist
        </Button>
      </div>

      <div className="rounded-lg border-2 border-white bg-black p-6">
        <h2 className="mb-4 text-xl font-semibold">Preview</h2>
        {renderPreview()}
      </div>
    </div>
  );
}