"use client";
import { useState } from "react";
import { Loader2, Settings2, Trash2, XIcon } from "lucide-react";
import { toast } from "sonner";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "shadcn_components/ui/alert-dialog";
import { Button } from "shadcn_components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogTitle,
  DialogTrigger,
} from "shadcn_components/ui/dialog";
import { Input } from "shadcn_components/ui/input";
import {
  useCategories,
  useDeleteCategory,
  useUpdateCategory,
} from "~/hooks/useBacklog";
import type { CategoryData } from "~/lib/api/backlog";
import { CATEGORY_NAME_MAX_LENGTH, categoryNameError } from "~/lib/categories";

interface CategoryRowProps {
  category: CategoryData;
  otherNames: string[];
  onDelete: (category: CategoryData) => void;
}

const CategoryRow = ({ category, otherNames, onDelete }: CategoryRowProps) => {
  const updateCategory = useUpdateCategory();
  const [name, setName] = useState(category.name);
  const [color, setColor] = useState(category.color);
  const error = categoryNameError(name, otherNames);

  const save = async (changes: { categoryName?: string; color?: string }) => {
    try {
      await updateCategory.mutateAsync({
        categoryId: category.id,
        changes,
      });
    } catch (saveError) {
      toast.error(
        saveError instanceof Error
          ? saveError.message
          : "Failed to update category",
      );
    }
  };

  const commitName = () => {
    const trimmed = name.trim();
    if (trimmed.length === 0 || error) {
      setName(category.name);
      return;
    }
    if (trimmed !== category.name) void save({ categoryName: trimmed });
  };

  const commitColor = () => {
    if (color !== category.color) void save({ color });
  };

  return (
    <li className="flex flex-col gap-1">
      <div className="flex items-center gap-2">
        <input
          type="color"
          aria-label={`Colour of ${category.name}`}
          value={color}
          onChange={(event) => setColor(event.target.value)}
          onBlur={commitColor}
          className="h-9 w-10 shrink-0 cursor-pointer rounded border border-white/40 bg-transparent p-0.5"
        />
        <Input
          aria-label={`Name of ${category.name}`}
          aria-invalid={error !== ""}
          value={name}
          maxLength={CATEGORY_NAME_MAX_LENGTH}
          onChange={(event) => setName(event.target.value)}
          onBlur={commitName}
          onKeyDown={(event) => {
            if (event.key === "Enter") event.currentTarget.blur();
          }}
        />
        <Button
          type="button"
          variant="ghost"
          size="icon"
          aria-label={`Delete ${category.name}`}
          onClick={() => onDelete(category)}
        >
          <Trash2 className="h-4 w-4" />
        </Button>
      </div>
      {error && <p className="pl-12 text-sm text-red-400">{error}</p>}
    </li>
  );
};

/**
 * Dialog to rename, recolour and delete the user's categories. Renames
 * and colour changes are saved when a field loses focus (or Enter is
 * pressed); deleting asks for confirmation because it removes the
 * category from every game that uses it.
 */
export const CategoryManager = () => {
  const { data: categories = [] } = useCategories();
  const deleteCategory = useDeleteCategory();
  const [pendingDelete, setPendingDelete] = useState<CategoryData | null>(null);

  const handleDelete = async () => {
    if (!pendingDelete) return;
    try {
      await deleteCategory.mutateAsync(pendingDelete.id);
      toast.success(`Category "${pendingDelete.name}" deleted`);
      setPendingDelete(null);
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Failed to delete category",
      );
    }
  };

  return (
    <>
      <Dialog>
        <DialogTrigger asChild>
          <Button type="button" variant="outline" size="sm" className="gap-2">
            <Settings2 className="h-4 w-4" />
            Manage
          </Button>
        </DialogTrigger>
        <DialogContent
          showCloseButton={false}
          aria-describedby={undefined}
          className="surface-glow border-2 border-white p-5 sm:max-w-md"
        >
          <DialogClose asChild>
            <Button
              variant="destructive"
              size="icon"
              aria-label="Close"
              className="absolute top-3 right-3 h-8 w-8"
            >
              <XIcon className="h-4 w-4 text-black" />
            </Button>
          </DialogClose>
          <DialogTitle>Manage categories</DialogTitle>
          {categories.length === 0 ? (
            <p className="text-sm text-white/70">
              No categories yet - create one from a game&apos;s Overview tab.
            </p>
          ) : (
            <ul className="flex max-h-[60vh] flex-col gap-3 overflow-y-auto pr-1">
              {categories.map((category) => (
                <CategoryRow
                  key={category.id}
                  category={category}
                  otherNames={categories
                    .filter((other) => other.id !== category.id)
                    .map((other) => other.name)}
                  onDelete={setPendingDelete}
                />
              ))}
            </ul>
          )}
        </DialogContent>
      </Dialog>

      <AlertDialog
        open={pendingDelete !== null}
        onOpenChange={(open) => {
          if (!open) setPendingDelete(null);
        }}
      >
        <AlertDialogContent className="bg-background border-2 border-red-600">
          <AlertDialogHeader>
            <AlertDialogTitle>
              Delete &quot;{pendingDelete?.name}&quot;?
            </AlertDialogTitle>
            <AlertDialogDescription className="text-white/70">
              The category is removed from every game that uses it. The games
              themselves stay in your backlog.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              disabled={deleteCategory.isPending}
              className="bg-red-600 text-white hover:bg-red-700"
            >
              {deleteCategory.isPending ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <Trash2 className="h-4 w-4" />
              )}
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
};
