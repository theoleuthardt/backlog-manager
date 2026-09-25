import { describe, expect, it } from "vitest";
import {
  BUILTIN_THEMES,
  DEFAULT_THEME_ID,
  isHexColor,
  newCustomThemeId,
  resolveTheme,
  themeCssVariables,
  type CustomTheme,
} from "~/lib/themes";

const customTheme: CustomTheme = {
  id: "custom-neon",
  name: "Neon",
  background: "#0a0014",
  surface: "#1a0033",
  foreground: "#f5e9ff",
  accent: "#ff2bd6",
  border: "#5b2a86",
  glow: "#00e5ff",
};

describe("resolveTheme", () => {
  it("resolves a built-in theme by id", () => {
    const theme = resolveTheme("light", []);

    expect(theme.id).toBe("light");
    expect(theme.builtin).toBe(true);
  });

  it("resolves a custom theme by id", () => {
    const theme = resolveTheme("custom-neon", [customTheme]);

    expect(theme.id).toBe("custom-neon");
    expect(theme.builtin).toBe(false);
    expect(theme.colors.accent).toBe("#ff2bd6");
  });

  it("falls back to the default theme for an unknown id", () => {
    expect(resolveTheme("deleted-theme", []).id).toBe(DEFAULT_THEME_ID);
  });

  it("ships light, dark, colorful and freaky as built-in themes", () => {
    expect(BUILTIN_THEMES.map((theme) => theme.id)).toEqual([
      "dark",
      "light",
      "colorful",
      "freaky",
    ]);
  });
});

describe("themeCssVariables", () => {
  it("maps the six theme colours to the --t-* custom properties", () => {
    expect(themeCssVariables(customTheme)).toEqual({
      "--t-background": "#0a0014",
      "--t-surface": "#1a0033",
      "--t-foreground": "#f5e9ff",
      "--t-accent": "#ff2bd6",
      "--t-border": "#5b2a86",
      "--t-glow": "#00e5ff",
      "--t-on-accent": "#000000",
      "--t-icon-filter": "invert(0)",
    });
  });

  it("inverts the white icon set when the foreground colour is dark", () => {
    const light = resolveTheme("light", []);

    expect(themeCssVariables(light.colors)["--t-icon-filter"]).toBe(
      "invert(1)",
    );
  });

  it("picks white text for a dark accent", () => {
    const variables = themeCssVariables({ ...customTheme, accent: "#1d2b8f" });

    expect(variables["--t-on-accent"]).toBe("#ffffff");
  });
});

describe("isHexColor", () => {
  it.each(["#000000", "#FfAa00", "#0a0014"])("accepts %s", (value) => {
    expect(isHexColor(value)).toBe(true);
  });

  it.each(["#fff", "red", "#gggggg", "url(x)", "#0000000", ""])(
    "rejects %s",
    (value) => {
      expect(isHexColor(value)).toBe(false);
    },
  );
});

describe("newCustomThemeId", () => {
  it("never collides with a built-in or existing custom theme id", () => {
    const taken = [...BUILTIN_THEMES.map((theme) => theme.id), "custom-abc"];

    const id = newCustomThemeId(taken);

    expect(taken).not.toContain(id);
    expect(id.startsWith("custom-")).toBe(true);
  });
});
