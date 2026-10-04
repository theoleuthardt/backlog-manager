"use client";
import { Play } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogTrigger,
} from "shadcn_components/ui/dialog";

interface TrailerDialogProps {
  title: string;
  embedUrl: string;
  watchUrl: string;
}

/**
 * Play card that opens the trailer in its own dialog, sized to the largest
 * 16:9 player that fits the viewport (the entry dialog itself is too short
 * to show a full-size video). The iframe only exists while the dialog is
 * open, so closing it also stops the video. The desktop app's webview
 * sends no HTTP referrer, which makes YouTube refuse some embeds with
 * error 153, so the dialog always offers the video on youtube.com as a
 * fallback below the player.
 */
export const TrailerDialog = ({
  title,
  embedUrl,
  watchUrl,
}: TrailerDialogProps) => (
  <Dialog>
    <DialogTrigger asChild>
      <button
        type="button"
        className="surface-glow bg-surface group flex w-full cursor-pointer flex-col items-center justify-center gap-3 rounded-xl border border-white/30 p-10 transition-colors hover:bg-white/10"
      >
        <span className="bg-primary text-primary-foreground flex h-16 w-16 items-center justify-center rounded-full transition-transform group-hover:scale-110">
          <Play className="h-7 w-7 fill-current" />
        </span>
        <span className="text-lg font-semibold">Watch trailer</span>
        <span className="text-sm text-white/70">Opens in a larger player</span>
      </button>
    </DialogTrigger>
    <DialogContent
      className="surface-glow bg-background max-w-none gap-0 overflow-hidden rounded-xl border-2 border-white p-0 sm:max-w-none"
      style={{ width: "min(96vw, calc((92dvh - 3rem) * 16 / 9))" }}
      aria-describedby={undefined}
    >
      <DialogTitle className="truncate px-4 py-3 pr-12 text-base font-bold">
        {title} trailer
      </DialogTitle>
      <div className="aspect-video w-full bg-black">
        <iframe
          src={embedUrl}
          title={`${title} trailer`}
          className="h-full w-full"
          allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
          allowFullScreen
          referrerPolicy="strict-origin-when-cross-origin"
        />
      </div>
      {watchUrl && (
        <a
          href={watchUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="px-4 py-3 text-sm text-white/70 underline-offset-2 hover:text-white hover:underline"
        >
          Video not playing? Watch it on YouTube
        </a>
      )}
    </DialogContent>
  </Dialog>
);
