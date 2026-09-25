"use client";
import { useEffect, useState } from "react";
import { Pencil, Plus, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "shadcn_components/ui/button";
import { Input } from "shadcn_components/ui/input";
import { Label } from "shadcn_components/ui/label";
import { useTheme } from "~/app/context/ThemeContext";
import {
  BUILTIN_THEMES,
  MAX_CUSTOM_THEMES,
  THEME_NAME_MAX_LENGTH,
  isHexColor,
  newCustomThemeId,
  type ThemeColors,
} from "~/lib/themes";

const COLOR_FIELDS: { key: keyof ThemeColors; label: string; hint: string }[] =
  [
    { key: "background", label: "Background", hint: "Page background" },
    { key: "surface", label: "Surface", hint: "Cards, dialogs and menus" },
    { key: "foreground", label: "Text", hint: "Text and icons" },
    { key: "accent", label: "Accent", hint: "Buttons and highlights" },
    { key: "border", label: "Border", hint: "Outlines and dividers" },
    { key: "glow", label: "Glow", hint: "Glow and gradient tint" },
  ];

export const ThemeCreator = () => {
  const {
    theme,
    customThemes,
    saveCustomTheme,
    deleteCustomTheme,
    previewColors,
  } = useTheme();
  const [editingId, setEditingId] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [colors, setColors] = useState<ThemeColors>(theme.colors);
  const [isSaving, setIsSaving] = useState(false);

  const trimmedName = name.trim();
  const allColorsValid = COLOR_FIELDS.every((field) =>
    isHexColor(colors[field.key]),
  );
  const atLimit =
    editingId === null && customThemes.length >= MAX_CUSTOM_THEMES;
  const canSave = trimmedName.length > 0 && allColorsValid && !atLimit;

  useEffect(() => () => previewColors(null), [previewColors]);

  const updateColors = (next: ThemeColors) => {
    setColors(next);
    previewColors(
      COLOR_FIELDS.every((field) => isHexColor(next[field.key])) ? next : null,
    );
  };

  const startNew = (base: ThemeColors) => {
    setEditingId(null);
    setName("");
    updateColors(base);
  };

  const startEditing = (id: string) => {
    const existing = customThemes.find((custom) => custom.id === id);
    if (!existing) return;
    setEditingId(id);
    setName(existing.name);
    updateColors({
      background: existing.background,
      surface: existing.surface,
      foreground: existing.foreground,
      accent: existing.accent,
      border: existing.border,
      glow: existing.glow,
    });
  };

  const handleSave = async () => {
    if (!canSave) return;
    setIsSaving(true);
    const id =
      editingId ??
      newCustomThemeId([
        ...BUILTIN_THEMES.map((builtin) => builtin.id),
        ...customThemes.map((custom) => custom.id),
      ]);
    const saved = await saveCustomTheme({ id, name: trimmedName, ...colors });
    setIsSaving(false);
    if (!saved) return;
    setEditingId(id);
    toast.success(`Theme "${trimmedName}" saved`);
  };

  const handleDelete = async (id: string, themeName: string) => {
    const deleted = await deleteCustomTheme(id);
    if (!deleted) return;
    if (editingId === id) startNew(colors);
    toast.success(`Theme "${themeName}" deleted`);
  };

  return (
    <div className="flex flex-col gap-8">
      <div>
        <h1 className="text-3xl font-bold">Theme creator</h1>
        <p className="mt-1 text-sm text-white/70">
          Changes preview live across the whole app. Save to keep the theme on
          your account and switch to it.
        </p>
      </div>

      <div className="grid gap-8 lg:grid-cols-[minmax(0,26rem)_1fr]">
        <section className="surface-glow bg-surface flex flex-col gap-4 rounded-xl border-2 border-white p-6">
          <div className="space-y-2">
            <Label htmlFor="theme-name">Theme name</Label>
            <Input
              id="theme-name"
              value={name}
              maxLength={THEME_NAME_MAX_LENGTH}
              onChange={(event) => setName(event.target.value)}
              placeholder="e.g. Neon Night"
            />
          </div>

          <div className="space-y-1">
            <Label>Start from</Label>
            <div className="flex flex-wrap gap-2">
              {BUILTIN_THEMES.map((builtin) => (
                <Button
                  key={builtin.id}
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => updateColors(builtin.colors)}
                >
                  {builtin.name}
                </Button>
              ))}
            </div>
          </div>

          <div className="flex flex-col gap-3">
            {COLOR_FIELDS.map((field) => {
              const value = colors[field.key];
              const valid = isHexColor(value);
              return (
                <div key={field.key} className="flex items-center gap-3">
                  <input
                    type="color"
                    aria-label={`${field.label} colour`}
                    value={valid ? value : "#000000"}
                    onChange={(event) =>
                      updateColors({
                        ...colors,
                        [field.key]: event.target.value,
                      })
                    }
                    className="h-10 w-12 shrink-0 cursor-pointer rounded border border-white/40 bg-transparent p-0.5"
                  />
                  <div className="min-w-0 flex-1">
                    <Label htmlFor={`color-${field.key}`} className="text-sm">
                      {field.label}
                    </Label>
                    <p className="truncate text-xs text-white/60">
                      {field.hint}
                    </p>
                  </div>
                  <Input
                    id={`color-${field.key}`}
                    value={value}
                    maxLength={7}
                    aria-invalid={!valid}
                    onChange={(event) =>
                      updateColors({
                        ...colors,
                        [field.key]: event.target.value,
                      })
                    }
                    className="w-28 font-mono"
                  />
                </div>
              );
            })}
          </div>

          <div className="flex flex-wrap gap-2 pt-2">
            <Button
              type="button"
              onClick={() => void handleSave()}
              disabled={!canSave || isSaving}
            >
              {editingId ? "Save changes" : "Save theme"}
            </Button>
            {editingId && (
              <Button
                type="button"
                variant="outline"
                onClick={() => startNew(colors)}
              >
                <Plus className="h-4 w-4" />
                New theme
              </Button>
            )}
          </div>
          {atLimit && (
            <p className="text-sm text-red-400">
              You can keep up to {MAX_CUSTOM_THEMES} custom themes - delete one
              to save another.
            </p>
          )}
        </section>

        <section className="flex flex-col gap-4">
          <h2 className="text-xl font-semibold">Your themes</h2>
          {customThemes.length === 0 ? (
            <p className="text-sm text-white/70">
              No custom themes yet - pick some colours and save your first one.
            </p>
          ) : (
            <ul className="grid gap-3 sm:grid-cols-2">
              {customThemes.map((custom) => (
                <li
                  key={custom.id}
                  className="bg-surface flex items-center gap-3 rounded-lg border border-white/40 p-3"
                >
                  <span
                    aria-hidden="true"
                    className="flex h-8 w-14 shrink-0 overflow-hidden rounded border border-white/40"
                  >
                    <span
                      className="flex-1"
                      style={{ backgroundColor: custom.background }}
                    />
                    <span
                      className="flex-1"
                      style={{ backgroundColor: custom.accent }}
                    />
                    <span
                      className="flex-1"
                      style={{ backgroundColor: custom.glow }}
                    />
                  </span>
                  <span className="min-w-0 flex-1 truncate font-medium">
                    {custom.name}
                    {theme.id === custom.id && (
                      <span className="ml-2 text-xs text-white/60">active</span>
                    )}
                  </span>
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon"
                    aria-label={`Edit ${custom.name}`}
                    onClick={() => startEditing(custom.id)}
                  >
                    <Pencil className="h-4 w-4" />
                  </Button>
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon"
                    aria-label={`Delete ${custom.name}`}
                    onClick={() => void handleDelete(custom.id, custom.name)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </div>
  );
};
