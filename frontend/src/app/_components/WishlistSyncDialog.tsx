import React, { useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { toast } from "sonner";
import { Button } from "shadcn_components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "shadcn_components/ui/dialog";
import {
  dismissWishlistSyncReport,
  getWishlistSyncReport,
} from "~/lib/api/steam";
import {
  hasWishlistChanges,
  wishlistDiffRows,
  wishlistSyncSummary,
} from "~/lib/wishlistSyncReport";

const REPORT_KEY = ["wishlist-sync-report"] as const;

/**
 * Information-only popup shown on the dashboard after the automatic Steam
 * wishlist sync changed the backlog since the user last looked: a diff of
 * the games it removed and added. Closing it clears the report on the
 * server, so it appears once.
 */
export const WishlistSyncDialog = () => {
  const [closed, setClosed] = useState(false);
  const { data: report } = useQuery({
    queryKey: REPORT_KEY,
    queryFn: getWishlistSyncReport,
    staleTime: Infinity,
  });
  const dismiss = useMutation({
    mutationFn: dismissWishlistSyncReport,
    onError: (error) => toast.error(error.message),
  });

  if (!report || !hasWishlistChanges(report)) return null;

  const handleOpenChange = (open: boolean) => {
    if (open || closed) return;
    setClosed(true);
    dismiss.mutate();
  };

  return (
    <Dialog open={!closed} onOpenChange={handleOpenChange}>
      <DialogContent className="surface-glow bg-background max-w-lg border-2 border-white">
        <DialogHeader>
          <DialogTitle>Your Steam wishlist changed</DialogTitle>
          <DialogDescription>{wishlistSyncSummary(report)}</DialogDescription>
        </DialogHeader>
        <ul
          aria-label="Wishlist changes"
          className="max-h-80 overflow-y-auto rounded-md border border-white/20 bg-black p-2 font-mono text-sm"
        >
          {wishlistDiffRows(report).map((row) => (
            <li
              key={`${row.sign}${row.steamAppId}`}
              className={`flex gap-2 rounded px-2 py-0.5 ${
                row.sign === "+"
                  ? "bg-green-500/10 text-green-400"
                  : "bg-red-500/10 text-red-400"
              }`}
            >
              <span aria-label={row.sign === "+" ? "added" : "removed"}>
                {row.sign}
              </span>
              <span className="min-w-0 truncate">{row.title}</span>
            </li>
          ))}
        </ul>
        <DialogFooter>
          <Button onClick={() => handleOpenChange(false)}>Close</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};
