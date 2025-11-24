/**
 * Tauri integration utilities
 * This file provides helper functions to check if the app is running in Tauri
 * and to safely invoke Tauri APIs
 */

// Check if we're running in a Tauri environment
export function isTauri(): boolean {
  if (typeof window === "undefined") return false;

  return "__TAURI__" in window;
}

// Safe wrapper for Tauri commands
export async function invokeTauriCommand<T>(
  command: string,
  args?: Record<string, unknown>,
): Promise<T | null> {
  if (!isTauri()) {
    console.warn("Tauri commands are only available in desktop app");
    return null;
  }

  try {
    const { invoke } = await import("@tauri-apps/api/core");
    return await invoke<T>(command, args);
  } catch (error) {
    console.error(`Failed to invoke Tauri command ${command}:`, error);
    throw error;
  }
}

// Example: Get app version
export async function getAppVersion(): Promise<string> {
  if (!isTauri()) {
    return "web";
  }

  try {
    const { getVersion } = await import("@tauri-apps/api/app");
    return await getVersion();
  } catch (error) {
    console.error("Failed to get app version:", error);
    return "unknown";
  }
}

// Example: Show native dialog
export async function showDialog(
  title: string,
  message: string,
): Promise<void> {
  if (!isTauri()) {
    alert(message); // Fallback for web
    return;
  }

  try {
    const { message: showMessage } = await import("@tauri-apps/plugin-dialog");
    await showMessage(message, { title });
  } catch (error) {
    console.error("Failed to show dialog:", error);
    alert(message); // Fallback
  }
}