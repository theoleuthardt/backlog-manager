"use client";
import { useRef, useState } from "react";
import { Check, Plus, X } from "lucide-react";
import { toast } from "sonner";
import { CategoryManager } from "components/CategoryManager";
import { Button } from "shadcn_components/ui/button";
import { Input } from "shadcn_components/ui/input";
import { Label } from "shadcn_components/ui/label";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "shadcn_components/ui/popover";
import {
  useCategories,
  useCreateCategory,
  useEntryCategories,
  useSetEntryCategory,
} from "~/hooks/useBacklog";
import {
  CATEGORY_NAME_MAX_LENGTH,
  categoryNameError,
  nextCategoryColor,
} from "~/lib/categories";

/**
 * Categories of one entry, shown next to the status in the dialog
 * hero: coloured chips (click the x to remove), a popover to toggle existing categories or create a new one that is
 * assigned right away, and the manage dialog for renaming, recolouring
 * and deleting. Changes are saved immediately, independent of the
 * entry form's Update button. After creating, focus returns to the name
 * field: the create button disables itself, and losing focus to the
 * body would make the dialog's focus trap dismiss the popover.
 */
export const CategoryPicker = ({ entryId }: { entryId: number }) => {
  const { data: categories = [] } = useCategories();
  const { data: byEntry } = useEntryCategories();
  const setEntryCategory = useSetEntryCategory();
  const createCategory = useCreateCategory();
  const [newName, setNewName] = useState("");
  const [newColor, setNewColor] = useState<string | null>(null);
  const nameInputRef = useRef<HTMLInputElement>(null);

  const assigned = byEntry?.get(entryId) ?? [];
  const assignedIds = new Set(assigned.map((category) => category.id));
  const color = newColor ?? nextCategoryColor(categories.length);
  const nameError = categoryNameError(
    newName,
    categories.map((category) => category.name),
  );
  const canCreate = newName.trim().length > 0 && nameError === "";

  const toggle = async (categoryId: number, shouldAssign: boolean) => {
    try {
      await setEntryCategory.mutateAsync({
        entryId,
        categoryId,
        assigned: shouldAssign,
      });
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Failed to update categories",
      );
    }
  };

  const handleCreate = async () => {
    if (!canCreate) return;
    try {
      const created = await createCategory.mutateAsync({
        categoryName: newName.trim(),
        color,
      });
      await setEntryCategory.mutateAsync({
        entryId,
        categoryId: created.id,
        assigned: true,
      });
      setNewName("");
      setNewColor(null);
      nameInputRef.current?.focus();
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Failed to create category",
      );
    }
  };

  return (
    <div role="group" aria-label="Categories">
      <div className="flex flex-wrap items-center gap-2">
        {assigned.map((category) => (
          <span
            key={category.id}
            className="flex items-center gap-1.5 rounded-full border border-white/30 bg-white/10 py-0.5 pr-1 pl-2.5 text-xs font-medium"
          >
            <span
              aria-hidden="true"
              className="h-2 w-2 rounded-full"
              style={{ backgroundColor: category.color }}
            />
            <span className="max-w-36 truncate">{category.name}</span>
            <button
              type="button"
              aria-label={`Remove ${category.name}`}
              onClick={() => void toggle(category.id, false)}
              className="cursor-pointer rounded-full p-0.5 hover:bg-white/20"
            >
              <X className="h-3 w-3" />
            </button>
          </span>
        ))}

        <Popover>
          <PopoverTrigger asChild>
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="gap-1.5"
            >
              <Plus className="h-4 w-4" />
              Category
            </Button>
          </PopoverTrigger>
          <PopoverContent className="w-72 space-y-3" align="start">
            {categories.length > 0 && (
              <ul className="flex max-h-48 flex-col gap-1 overflow-y-auto">
                {categories.map((category) => {
                  const isAssigned = assignedIds.has(category.id);
                  return (
                    <li key={category.id}>
                      <button
                        type="button"
                        role="checkbox"
                        aria-checked={isAssigned}
                        onClick={() => void toggle(category.id, !isAssigned)}
                        className="flex w-full cursor-pointer items-center gap-2 rounded-md px-2 py-1.5 text-left text-sm hover:bg-white/10"
                      >
                        <span
                          aria-hidden="true"
                          className="h-3 w-3 shrink-0 rounded-full"
                          style={{ backgroundColor: category.color }}
                        />
                        <span className="min-w-0 flex-1 truncate">
                          {category.name}
                        </span>
                        {isAssigned && <Check className="h-4 w-4" />}
                      </button>
                    </li>
                  );
                })}
              </ul>
            )}
            <div className="space-y-2 border-t border-white/20 pt-3">
              <Label htmlFor="new-category-name" className="text-xs">
                New category
              </Label>
              <div className="flex items-center gap-2">
                <input
                  type="color"
                  aria-label="Category colour"
                  value={color}
                  onChange={(event) => setNewColor(event.target.value)}
                  className="h-9 w-10 shrink-0 cursor-pointer rounded border border-white/40 bg-transparent p-0.5"
                />
                <Input
                  ref={nameInputRef}
                  id="new-category-name"
                  value={newName}
                  maxLength={CATEGORY_NAME_MAX_LENGTH}
                  placeholder="e.g. Co-op nights"
                  aria-invalid={nameError !== ""}
                  onChange={(event) => setNewName(event.target.value)}
                  onKeyDown={(event) => {
                    if (event.key === "Enter") void handleCreate();
                  }}
                />
              </div>
              {nameError && <p className="text-sm text-red-400">{nameError}</p>}
              <Button
                type="button"
                size="sm"
                className="w-full"
                disabled={!canCreate || createCategory.isPending}
                onClick={() => void handleCreate()}
              >
                Create and add
              </Button>
            </div>
          </PopoverContent>
        </Popover>
        <CategoryManager />
      </div>
    </div>
  );
};
