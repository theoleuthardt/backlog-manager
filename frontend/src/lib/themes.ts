export interface ThemeColors {
  background: string;
  surface: string;
  foreground: string;
  accent: string;
  border: string;
  glow: string;
}

export interface CustomTheme extends ThemeColors {
  id: string;
  name: string;
}

export interface BuiltinTheme {
  id: "dark" | "light" | "colorful" | "freaky";
  name: string;
  colors: ThemeColors;
}

export interface ResolvedTheme {
  id: string;
  name: string;
  colors: ThemeColors;
  builtin: boolean;
}

export const BUILTIN_THEMES: readonly BuiltinTheme[] = [
  {
    id: "dark",
    name: "Dark",
    colors: {
      background: "#000000",
      surface: "#0f0f12",
      foreground: "#ffffff",
      accent: "#2563eb",
      border: "#ffffff",
      glow: "#3b82f6",
    },
  },
  {
    id: "light",
    name: "Light",
    colors: {
      background: "#f5f4ef",
      surface: "#ffffff",
      foreground: "#15151b",
      accent: "#4f46e5",
      border: "#15151b",
      glow: "#818cf8",
    },
  },
  {
    id: "colorful",
    name: "Colorful",
    colors: {
      background: "#0b0720",
      surface: "#1a1240",
      foreground: "#fdf2ff",
      accent: "#ff3ea5",
      border: "#7c4dff",
      glow: "#22d3ee",
    },
  },
  {
    id: "freaky",
    name: "Freaky",
    colors: {
      background: "#04040e",
      surface: "#0e0e26",
      foreground: "#eaffe9",
      accent: "#a3ff12",
      border: "#00ffd0",
      glow: "#ff00e5",
    },
  },
];

export const DEFAULT_THEME_ID = "dark";
export const THEME_CACHE_KEY = "blm-theme";
export const MAX_CUSTOM_THEMES = 10;
export const THEME_NAME_MAX_LENGTH = 30;

const HEX_COLOR = /^#[0-9a-fA-F]{6}$/;

export function isHexColor(value: string): boolean {
  return HEX_COLOR.test(value);
}

export function resolveTheme(
  themeId: string,
  customThemes: readonly CustomTheme[],
): ResolvedTheme {
  const builtin = BUILTIN_THEMES.find((theme) => theme.id === themeId);
  if (builtin) return { ...builtin, builtin: true };

  const custom = customThemes.find((theme) => theme.id === themeId);
  if (custom) {
    const { id, name, ...colors } = custom;
    return { id, name, colors, builtin: false };
  }

  return resolveTheme(DEFAULT_THEME_ID, []);
}

function relativeLuminance(hex: string): number {
  const [red, green, blue] = [1, 3, 5].map((offset) => {
    const channel = parseInt(hex.slice(offset, offset + 2), 16) / 255;
    return channel <= 0.03928
      ? channel / 12.92
      : Math.pow((channel + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * (red ?? 0) + 0.7152 * (green ?? 0) + 0.0722 * (blue ?? 0);
}

/**
 * Black or white, whichever has the higher WCAG contrast against
 * `accent` (the two contrast equally at a relative luminance of about
 * 0.179) - accent-filled buttons and badges use it as their text colour.
 */
function onAccentColor(accent: string): string {
  return relativeLuminance(accent) > 0.179 ? "#000000" : "#ffffff";
}

export function themeCssVariables(colors: ThemeColors): Record<string, string> {
  return {
    "--t-background": colors.background,
    "--t-surface": colors.surface,
    "--t-foreground": colors.foreground,
    "--t-accent": colors.accent,
    "--t-border": colors.border,
    "--t-glow": colors.glow,
    "--t-on-accent": onAccentColor(colors.accent),
    "--t-icon-filter":
      relativeLuminance(colors.foreground) < 0.5 ? "invert(1)" : "invert(0)",
  };
}

export function newCustomThemeId(takenIds: readonly string[]): string {
  let id: string;
  do {
    id = `custom-${crypto.randomUUID().slice(0, 8)}`;
  } while (takenIds.includes(id));
  return id;
}
