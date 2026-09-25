"use client";
import * as Dialog from "@radix-ui/react-dialog";
import { AnimatePresence, motion, useDragControls } from "motion/react";

interface BottomSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  footer: React.ReactNode;
  children: React.ReactNode;
}

/**
 * Phone-friendly panel that slides up from the bottom edge. It can be
 * dismissed by tapping the dimmed background, pressing Escape, or
 * dragging the handle down; the footer stays pinned below the scrolling
 * content so the primary action is always in thumb reach.
 */
export const BottomSheet = ({
  open,
  onOpenChange,
  title,
  footer,
  children,
}: BottomSheetProps) => {
  const dragControls = useDragControls();

  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <AnimatePresence>
        {open && (
          <Dialog.Portal forceMount>
            <Dialog.Overlay asChild forceMount>
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="fixed inset-0 z-50 bg-black/60 backdrop-blur-[2px]"
              />
            </Dialog.Overlay>
            <Dialog.Content
              asChild
              forceMount
              aria-describedby={undefined}
              onOpenAutoFocus={(event) => event.preventDefault()}
            >
              <motion.div
                drag="y"
                dragControls={dragControls}
                dragListener={false}
                dragConstraints={{ top: 0, bottom: 0 }}
                dragElastic={{ top: 0, bottom: 0.6 }}
                onDragEnd={(_, info) => {
                  if (info.offset.y > 120 || info.velocity.y > 600) {
                    onOpenChange(false);
                  }
                }}
                initial={{ y: "100%" }}
                animate={{ y: 0 }}
                exit={{ y: "100%" }}
                transition={{ type: "spring", stiffness: 320, damping: 34 }}
                className="surface-glow bg-background fixed inset-x-0 bottom-0 z-50 flex max-h-[88dvh] flex-col rounded-t-3xl border-2 border-b-0 border-white"
              >
                <div
                  onPointerDown={(event) => dragControls.start(event)}
                  className="flex shrink-0 cursor-grab touch-none justify-center pt-3 pb-1"
                >
                  <span
                    aria-hidden="true"
                    className="h-1.5 w-12 rounded-full bg-white/40"
                  />
                </div>
                <Dialog.Title className="shrink-0 px-4 pb-3 text-lg font-bold">
                  {title}
                </Dialog.Title>
                <div className="min-h-0 flex-1 overflow-y-auto px-4 pb-4">
                  {children}
                </div>
                <div className="bg-surface shrink-0 border-t border-white/20 p-3 pb-[max(0.75rem,env(safe-area-inset-bottom))]">
                  {footer}
                </div>
              </motion.div>
            </Dialog.Content>
          </Dialog.Portal>
        )}
      </AnimatePresence>
    </Dialog.Root>
  );
};
