import { useSyncExternalStore } from "react";

// Never changes at runtime, so there's nothing to actually subscribe to -
// this is only using useSyncExternalStore for its dual snapshot/
// server-snapshot behavior, matching React's own recommended API for a
// value that must read as false during SSR/static-export prerendering
// (no window) and only reflects the real environment once mounted.
// eslint-disable-next-line @typescript-eslint/no-empty-function -- intentionally a no-op, nothing to unsubscribe from
const noopSubscribe = () => () => {};

function getSnapshot(): boolean {
  return "__TAURI_INTERNALS__" in window;
}

function getServerSnapshot(): boolean {
  return false;
}

export function useIsTauri(): boolean {
  return useSyncExternalStore(noopSubscribe, getSnapshot, getServerSnapshot);
}
