"use client";
import { useEffect } from "react";
import {
  motion,
  useMotionValue,
  useReducedMotion,
  useSpring,
} from "motion/react";
import { EntryTile } from "components/EntryTile";
import type { BacklogEntryData } from "~/lib/api/backlog";

const MAX_SWING_DEGREES = 30;
const DEGREES_PER_PIXEL = 2.2;
const IDLE_MS = 60;

/**
 * The card that follows the pointer while dragging. It must be rendered
 * through a portal into document.body (see DashboardContent): the
 * overlay is position: fixed, and any transformed ancestor - the page
 * transition and the drop-in animation both leave one - would become
 * its containing block and offset it by the scroll position. It hangs from its
 * top edge like a pendulum: horizontal pointer movement kicks it to the
 * opposite side, and an underdamped spring swings it back and forth
 * until it settles once the pointer stops. Touch and mouse both feed it
 * through window pointer/touch move events; users who prefer reduced
 * motion get a static card.
 */
export const DragPreview = ({ entry }: { entry: BacklogEntryData }) => {
  const prefersReducedMotion = useReducedMotion();
  const target = useMotionValue(0);
  const rotate = useSpring(target, { stiffness: 90, damping: 6.5, mass: 1 });

  useEffect(() => {
    if (prefersReducedMotion) return;
    let lastX: number | null = null;
    let idleTimer: ReturnType<typeof setTimeout> | undefined;

    const handleMove = (clientX: number) => {
      if (lastX !== null) {
        const swing = (clientX - lastX) * DEGREES_PER_PIXEL;
        target.set(
          Math.max(-MAX_SWING_DEGREES, Math.min(MAX_SWING_DEGREES, swing)),
        );
        clearTimeout(idleTimer);
        idleTimer = setTimeout(() => target.set(0), IDLE_MS);
      }
      lastX = clientX;
    };
    const handlePointerMove = (event: PointerEvent) =>
      handleMove(event.clientX);
    const handleTouchMove = (event: TouchEvent) => {
      const touch = event.touches[0];
      if (touch) handleMove(touch.clientX);
    };

    window.addEventListener("pointermove", handlePointerMove);
    window.addEventListener("touchmove", handleTouchMove, { passive: true });
    return () => {
      clearTimeout(idleTimer);
      window.removeEventListener("pointermove", handlePointerMove);
      window.removeEventListener("touchmove", handleTouchMove);
    };
  }, [prefersReducedMotion, target]);

  return (
    <motion.div
      style={{ rotate, transformOrigin: "50% 0%" }}
      initial={{ scale: 1 }}
      animate={{ scale: 1.06 }}
      className="opacity-90"
    >
      <EntryTile
        title={entry.title}
        imageLink={entry.imageLink}
        status={entry.status}
        playtime={entry.playtime}
        mainTime={entry.mainTime}
      />
    </motion.div>
  );
};
