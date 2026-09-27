import { Clock } from "lucide-react";
import { GameImage } from "components/GameImage";
import { statusColor } from "~/lib/statusStyle";

interface EntryTileProps {
  title: string;
  imageLink: string;
  imageAlt?: string;
  status?: string;
  playtime?: number;
  mainTime?: number;
}

/**
 * Cover card shown in the dashboard grid: the title sits on a gradient
 * over the bottom of the cover, a coloured dot marks the status, and a
 * thin bar shows playtime against the HowLongToBeat main-story time.
 */
export const EntryTile = ({
  title,
  imageLink,
  imageAlt,
  status,
  playtime,
  mainTime,
}: EntryTileProps) => {
  const progress =
    playtime !== undefined && mainTime !== undefined && mainTime > 0
      ? Math.min(100, (playtime / mainTime) * 100)
      : null;

  return (
    <div className="entry-tile group hover:surface-glow relative w-[9.375rem] cursor-pointer overflow-hidden rounded-xl leading-[0] transition-shadow duration-200">
      <GameImage
        src={imageLink}
        alt={imageAlt ?? title}
        width={150}
        height={225}
      />
      {status && (
        <span
          className="absolute top-2 left-2 flex max-w-[calc(100%-1rem)] items-center gap-1 rounded-full bg-black/70 px-2 py-0.5 text-[0.65rem] leading-4 font-medium text-white backdrop-blur-sm"
          title={status}
        >
          <span
            aria-hidden="true"
            className="h-2 w-2 shrink-0 rounded-full"
            style={{ backgroundColor: statusColor(status) }}
          />
          <span className="truncate">{status}</span>
        </span>
      )}
      <div className="absolute inset-x-0 bottom-0 flex flex-col gap-1 bg-gradient-to-t from-black/90 via-black/60 to-transparent px-2 pt-8 pb-2 leading-tight">
        <span className="line-clamp-2 text-sm font-semibold text-white">
          {title}
        </span>
        {playtime !== undefined && playtime > 0 && (
          <span className="flex items-center gap-1 text-[0.65rem] text-white/80">
            <Clock className="h-3 w-3" />
            {playtime}h{mainTime ? ` / ${mainTime}h` : ""}
          </span>
        )}
      </div>
      {progress !== null && (
        <div className="absolute inset-x-0 bottom-0 h-1 bg-white/20">
          <div
            className="bg-primary h-full"
            style={{ width: `${progress}%` }}
          />
        </div>
      )}
    </div>
  );
};
