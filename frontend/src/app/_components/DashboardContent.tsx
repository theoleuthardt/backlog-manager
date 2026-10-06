import React, { Suspense, lazy, useCallback, useMemo, useState } from "react";
import { createPortal } from "react-dom";
import {
  DndContext,
  DragOverlay,
  MouseSensor,
  TouchSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
  type DragStartEvent,
} from "@dnd-kit/core";
import { AnimatePresence, MotionConfig, motion } from "motion/react";
import {
  ChevronsLeft,
  Clock,
  ListChecks,
  Loader2,
  SlidersHorizontal,
} from "lucide-react";
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
import { Dialog } from "shadcn_components/ui/dialog";
import { BacklogEntry } from "components/BacklogEntry";
import { BottomSheet } from "components/BottomSheet";
import { BulkActionBar } from "components/BulkActionBar";
import { CategoryGroupSection } from "components/CategoryGroupSection";
import {
  DashboardSidebar,
  type FilterBounds,
} from "components/DashboardSidebar";
import { DraggableEntry } from "components/DraggableEntry";
import { DragPreview } from "components/DragPreview";
import { GroupSection } from "components/GroupSection";
import { IgdbSyncButton } from "components/IgdbSyncButton";
import { SteamSyncButton } from "components/SteamSyncButton";
import { StatusGroupSection } from "components/StatusGroupSection";
import { useAuth } from "~/app/context/AuthContext";
import { useDashboard } from "~/app/context/DashboardContext";
import {
  EntryActionsProvider,
  type EntryActions,
  type EntryRef,
} from "~/app/context/EntryActionsContext";
import { useTheme } from "~/app/context/ThemeContext";
import {
  useBacklogEntries,
  useBulkDeleteEntries,
  useBulkUpdateStatus,
  useCategories,
  useCustomStatuses,
  useEntryCategories,
  useMoveEntryToStatus,
  useSetEntryCategory,
} from "~/hooks/useBacklog";
import { useMediaQuery } from "~/hooks/useMediaQuery";
import { DEFAULT_STATUSES, type BacklogEntryData } from "~/lib/api/backlog";
import {
  countActiveFilters,
  EMPTY_FILTERS,
  filterEntries,
  type EntryFilters,
} from "~/lib/filterEntries";
import { sortCategoriesByName } from "~/lib/categories";
import { MAX_REVIEW_STARS } from "~/lib/reviewStars";
import { groupEntriesByStatus, groupSortedEntries } from "~/lib/groupEntries";
import {
  DEFAULT_SORT,
  defaultDirectionFor,
  isSortOption,
  sortEntries,
  type SortDirection,
  type SortOption,
} from "~/lib/sortEntries";

const EntryDetail = lazy(() =>
  import("components/EntryDetail").then((module) => ({
    default: module.EntryDetail,
  })),
);

function ceilMax(
  entries: readonly BacklogEntryData[],
  pick: (entry: BacklogEntryData) => number | undefined,
  minimum: number,
): number {
  const max = Math.max(0, ...entries.map((entry) => pick(entry) ?? 0));
  return Math.max(minimum, Math.ceil(max));
}

function uniqueSorted(values: Iterable<string>): string[] {
  return Array.from(new Set(values)).sort((a, b) => a.localeCompare(b));
}

/**
 * `toolbarStart` is rendered in the stats row, immediately left of the
 * Steam sync button (the shared space page puts its controls there).
 */
export const DashboardContent = ({
  toolbarStart,
}: {
  toolbarStart?: React.ReactNode;
} = {}) => {
  const { user } = useAuth();
  const { searchQuery } = useDashboard();
  const { theme } = useTheme();
  const { data: backlogData, isLoading, error } = useBacklogEntries();
  const { data: customStatuses = [] } = useCustomStatuses();
  const moveEntry = useMoveEntryToStatus();
  const setEntryCategory = useSetEntryCategory();
  const bulkUpdateStatus = useBulkUpdateStatus();
  const bulkDelete = useBulkDeleteEntries();

  const isDesktop = useMediaQuery("(min-width: 1024px)");
  const [sidebarToggle, setSidebarToggle] = useState<boolean | null>(null);
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const isSidebarOpen = sidebarToggle ?? false;

  const [selectedFilters, setFilters] = useState<EntryFilters>(EMPTY_FILTERS);
  const [sortOverride, setSortOverride] = useState<SortOption | null>(null);
  const [directionOverride, setDirectionOverride] =
    useState<SortDirection | null>(null);
  const [collapsedGroups, setCollapsedGroups] = useState<string[]>([]);
  const [draggedEntry, setDraggedEntry] = useState<BacklogEntryData | null>(
    null,
  );
  const [openEntryId, setOpenEntryId] = useState<number | null>(null);
  const [selectionMode, setSelectionMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<ReadonlySet<number>>(
    () => new Set(),
  );
  const [pendingDelete, setPendingDelete] = useState<
    readonly EntryRef[] | null
  >(null);

  const userDefaultSort =
    user && isSortOption(user.defaultSort) ? user.defaultSort : DEFAULT_SORT;
  const sortBy = sortOverride ?? userDefaultSort;
  const direction = directionOverride ?? defaultDirectionFor(sortBy);

  const entries = useMemo(() => backlogData ?? [], [backlogData]);
  const totalMainTime = useMemo(
    () => entries.reduce((sum, entry) => sum + (entry.mainTime ?? 0), 0),
    [entries],
  );

  const statusOptions = useMemo(
    () =>
      Array.from(
        new Set<string>([
          ...DEFAULT_STATUSES,
          ...customStatuses.map((status) => status.name),
          ...entries.map((entry) => entry.status),
        ]),
      ),
    [customStatuses, entries],
  );
  const platformOptions = useMemo(
    () => uniqueSorted(entries.flatMap((entry) => entry.platform)),
    [entries],
  );
  const genreOptions = useMemo(
    () => uniqueSorted(entries.flatMap((entry) => entry.genre)),
    [entries],
  );
  const bounds: FilterBounds = useMemo(
    () => ({
      interest: 10,
      reviewStars: MAX_REVIEW_STARS,
      playtime: ceilMax(entries, (entry) => entry.playtime, 10),
      mainTime: ceilMax(entries, (entry) => entry.mainTime, 10),
      mainPlusExtraTime: ceilMax(
        entries,
        (entry) => entry.mainPlusExtraTime,
        10,
      ),
      completionTime: ceilMax(entries, (entry) => entry.completionTime, 10),
    }),
    [entries],
  );

  const { data: entryCategories } = useEntryCategories();
  const { data: allCategories = [] } = useCategories();
  const sortedCategories = useMemo(
    () => sortCategoriesByName(allCategories),
    [allCategories],
  );
  const categoryOptions = useMemo(
    () =>
      allCategories
        .map((category) => category.name)
        .sort((a, b) => a.localeCompare(b)),
    [allCategories],
  );
  const filters = useMemo(
    () => ({
      ...selectedFilters,
      categories: selectedFilters.categories.filter((name) =>
        categoryOptions.includes(name),
      ),
    }),
    [selectedFilters, categoryOptions],
  );
  const categoryColors = useMemo(
    () =>
      new Map(allCategories.map((category) => [category.name, category.color])),
    [allCategories],
  );
  const categoryNamesByEntry = useMemo(
    () =>
      new Map(
        Array.from(entryCategories ?? [], ([entryId, list]) => [
          entryId,
          list.map((category) => category.name),
        ]),
      ),
    [entryCategories],
  );
  const firstCategoryByEntry = useMemo(
    () =>
      new Map(
        Array.from(categoryNamesByEntry, ([entryId, names]) => [
          entryId,
          names[0] ?? "",
        ]),
      ),
    [categoryNamesByEntry],
  );

  const visibleEntries = useMemo(
    () =>
      sortEntries(
        filterEntries(
          entries,
          { ...filters, search: searchQuery },
          categoryNamesByEntry,
        ),
        {
          sortBy,
          direction,
          statusOrder: statusOptions,
          categoryByEntryId: firstCategoryByEntry,
        },
      ),
    [
      entries,
      filters,
      searchQuery,
      sortBy,
      direction,
      statusOptions,
      categoryNamesByEntry,
      firstCategoryByEntry,
    ],
  );

  const groups = useMemo(() => {
    if (sortBy !== "status") return [];
    const order =
      direction === "asc" ? statusOptions : [...statusOptions].reverse();
    return groupEntriesByStatus(visibleEntries, order).filter(
      (group) =>
        filters.statuses.length === 0 ||
        filters.statuses.includes(group.status),
    );
  }, [sortBy, direction, statusOptions, visibleEntries, filters.statuses]);

  const labelGroups = useMemo(
    () =>
      sortBy === "status"
        ? []
        : groupSortedEntries(visibleEntries, sortBy, firstCategoryByEntry),
    [sortBy, visibleEntries, firstCategoryByEntry],
  );

  const categoryGroups = useMemo(() => {
    if (sortBy !== "category") return [];
    const present = new Set(labelGroups.map((group) => group.label));
    const empty = allCategories
      .map((category) => category.name)
      .filter((name) => !present.has(name))
      .sort((a, b) => a.localeCompare(b))
      .map((label) => ({ label, entries: [] as BacklogEntryData[] }));
    return [...labelGroups, ...empty];
  }, [sortBy, labelGroups, allCategories]);

  const sensors = useSensors(
    useSensor(MouseSensor, { activationConstraint: { distance: 8 } }),
    useSensor(TouchSensor, {
      activationConstraint: { delay: 250, tolerance: 8 },
    }),
  );

  const moveEntryMutate = moveEntry.mutate;
  const setEntryCategoryMutate = setEntryCategory.mutate;
  const changeStatus = useCallback(
    (entry: EntryRef, status: string) => {
      const previousStatus = entry.status;
      moveEntryMutate(
        { entryId: entry.id, status },
        {
          onSuccess: () =>
            toast.success(`Moved "${entry.title}" to ${status}`, {
              action: previousStatus
                ? {
                    label: "Undo",
                    onClick: () =>
                      moveEntryMutate({
                        entryId: entry.id,
                        status: previousStatus,
                      }),
                  }
                : undefined,
            }),
          onError: (moveError) =>
            toast.error(
              moveError instanceof Error
                ? moveError.message
                : "Failed to change status",
            ),
        },
      );
    },
    [moveEntryMutate],
  );

  const entryActions: EntryActions = useMemo(
    () => ({
      openEntry: setOpenEntryId,
      selectionMode,
      selectedIds,
      toggleSelected: (id) =>
        setSelectedIds((current) => {
          const next = new Set(current);
          if (!next.delete(id)) next.add(id);
          return next;
        }),
      startSelection: (id) => {
        setSelectionMode(true);
        setSelectedIds(new Set([id]));
      },
      requestDelete: setPendingDelete,
      changeStatus,
      statusOptions,
      categories: sortedCategories,
      categoriesByEntry: entryCategories ?? new Map(),
      toggleCategory: (entryId, categoryId, assigned) =>
        setEntryCategoryMutate(
          { entryId, categoryId, assigned },
          {
            onError: (error) =>
              toast.error(
                error instanceof Error
                  ? error.message
                  : "Failed to update categories",
              ),
          },
        ),
    }),
    [
      selectionMode,
      selectedIds,
      changeStatus,
      statusOptions,
      sortedCategories,
      entryCategories,
      setEntryCategoryMutate,
    ],
  );

  const endSelection = () => {
    setSelectionMode(false);
    setSelectedIds(new Set());
  };

  const selectedEntryRefs = entries
    .filter((entry) => selectedIds.has(entry.id))
    .map((entry) => ({ id: entry.id, title: entry.title }));

  const handleBulkStatus = async (status: string) => {
    const ids = selectedEntryRefs.map((entry) => entry.id);
    try {
      const result = await bulkUpdateStatus.mutateAsync({
        entryIds: ids,
        status,
      });
      if (result.failed > 0)
        toast.error(
          `Moved ${result.succeeded} to ${status}, ${result.failed} failed`,
        );
      else
        toast.success(
          `Moved ${result.succeeded} game${result.succeeded === 1 ? "" : "s"} to ${status}`,
        );
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Failed to change status",
      );
    }
  };

  const confirmDelete = async () => {
    if (!pendingDelete) return;
    const ids = pendingDelete.map((entry) => entry.id);
    try {
      const result = await bulkDelete.mutateAsync(ids);
      if (result.failed > 0)
        toast.error(`Deleted ${result.succeeded}, ${result.failed} failed`);
      else
        toast.success(
          ids.length === 1 && pendingDelete[0]
            ? `"${pendingDelete[0].title}" deleted`
            : `Deleted ${result.succeeded} games`,
        );
      setSelectedIds((current) => {
        const next = new Set(current);
        ids.forEach((id) => next.delete(id));
        return next;
      });
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Failed to delete games",
      );
    } finally {
      setPendingDelete(null);
    }
  };

  const handleDragStart = (event: DragStartEvent) => {
    setDraggedEntry(
      entries.find((entry) => entry.id === event.active.id) ?? null,
    );
  };

  const moveToCategory = async (
    entry: BacklogEntryData,
    targetName: string,
  ) => {
    const target = allCategories.find(
      (category) => category.name === targetName,
    );
    const assigned = entryCategories?.get(entry.id) ?? [];
    const source = assigned[0];
    if (!target || source?.id === target.id) return;
    try {
      if (!assigned.some((category) => category.id === target.id))
        await setEntryCategory.mutateAsync({
          entryId: entry.id,
          categoryId: target.id,
          assigned: true,
        });
      if (source)
        await setEntryCategory.mutateAsync({
          entryId: entry.id,
          categoryId: source.id,
          assigned: false,
        });
      toast.success(`Moved "${entry.title}" to ${target.name}`);
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Failed to change category",
      );
    }
  };

  const handleDragEnd = (event: DragEndEvent) => {
    setDraggedEntry(null);
    const entry = entries.find((candidate) => candidate.id === event.active.id);
    const target = event.over?.id;
    if (!entry || typeof target !== "string") return;
    if (sortBy === "category") void moveToCategory(entry, target);
    else if (target !== entry.status) changeStatus(entry, target);
  };

  const groupKey = (label: string) => `${sortBy}:${label}`;
  const toggleGroup = (label: string) =>
    setCollapsedGroups((collapsed) =>
      collapsed.includes(groupKey(label))
        ? collapsed.filter((value) => value !== groupKey(label))
        : [...collapsed, groupKey(label)],
    );

  if (isLoading) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <Loader2 className="text-primary h-12 w-12 animate-spin" />
          <p className="text-lg text-white">Loading your backlog...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <p className="text-lg text-red-500">Error loading backlog entries</p>
          <p className="text-sm text-white">{error.message}</p>
        </div>
      </div>
    );
  }

  const activeFilterCount = countActiveFilters(filters);
  const renderEntry = (entry: BacklogEntryData) => (
    <BacklogEntry key={entry.id} {...entry} />
  );
  const renderDraggableEntry = (entry: BacklogEntryData) => (
    <DraggableEntry key={entry.id} entry={entry} />
  );

  const sidebarPanel = (
    <DashboardSidebar
      sortBy={sortBy}
      direction={direction}
      onSortByChange={(next) => {
        setSortOverride(next);
        setDirectionOverride(null);
      }}
      onDirectionChange={setDirectionOverride}
      filters={filters}
      onFiltersChange={setFilters}
      platformOptions={platformOptions}
      genreOptions={genreOptions}
      statusOptions={statusOptions}
      categoryOptions={categoryOptions}
      bounds={bounds}
    />
  );

  const openEntry = entries.find((entry) => entry.id === openEntryId);

  return (
    <EntryActionsProvider value={entryActions}>
      <MotionConfig reducedMotion="user">
        <div
          id="upperSection"
          className="flex flex-col gap-4 py-2 lg:flex-row lg:gap-0"
        >
          {isDesktop && (
            <motion.aside
              id="leftBar"
              aria-label="Sort and filter"
              inert={!isSidebarOpen}
              initial={false}
              animate={{
                width: isSidebarOpen ? 304 : 0,
                marginRight: isSidebarOpen ? 24 : 0,
                opacity: isSidebarOpen ? 1 : 0,
              }}
              transition={{ type: "spring", stiffness: 260, damping: 30 }}
              className="sticky top-4 -m-2 shrink-0 self-start overflow-hidden"
            >
              <motion.div
                initial={false}
                animate={{ x: isSidebarOpen ? 0 : -32 }}
                transition={{ type: "spring", stiffness: 260, damping: 26 }}
                className="w-76 p-2"
              >
                <div className="surface-glow bg-surface max-h-[calc(100vh-9rem)] overflow-y-auto rounded-2xl border-2 border-white p-4">
                  {sidebarPanel}
                </div>
              </motion.div>
            </motion.aside>
          )}

          <div id="entryList" className="flex min-w-0 flex-1 flex-col gap-4">
            <div className="bg-background/85 sticky top-0 z-30 -mx-3 flex flex-wrap items-center gap-3 px-3 py-2 backdrop-blur-md md:-mx-4 md:px-4 lg:static lg:mx-0 lg:bg-transparent lg:p-0 lg:backdrop-blur-none">
              <motion.div
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.9 }}
                className="block"
              >
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() =>
                    isDesktop
                      ? setSidebarToggle(!isSidebarOpen)
                      : setIsSheetOpen(true)
                  }
                  aria-expanded={isDesktop ? isSidebarOpen : isSheetOpen}
                  aria-controls={isDesktop ? "leftBar" : undefined}
                  aria-haspopup={isDesktop ? undefined : "dialog"}
                  className={`gap-2 transition-shadow ${isSidebarOpen ? "surface-glow" : ""}`}
                >
                  <motion.span
                    animate={{ rotate: isSidebarOpen ? 0 : 180 }}
                    transition={{ type: "spring", stiffness: 300, damping: 15 }}
                    className="flex"
                  >
                    <SlidersHorizontal className="h-4 w-4" />
                  </motion.span>
                  Sort &amp; filter
                  <AnimatePresence>
                    {activeFilterCount > 0 && (
                      <motion.span
                        key="active-filter-count"
                        initial={{ scale: 0 }}
                        animate={{ scale: 1 }}
                        exit={{ scale: 0 }}
                        transition={{
                          type: "spring",
                          stiffness: 500,
                          damping: 18,
                        }}
                        className="bg-primary text-primary-foreground rounded-full px-1.5 text-xs"
                      >
                        {activeFilterCount}
                      </motion.span>
                    )}
                  </AnimatePresence>
                  <motion.span
                    aria-hidden="true"
                    animate={{ rotate: isSidebarOpen ? 0 : 180 }}
                    transition={{ type: "spring", stiffness: 300, damping: 18 }}
                    className="hidden lg:flex"
                  >
                    <ChevronsLeft className="h-4 w-4" />
                  </motion.span>
                </Button>
              </motion.div>
              <p className="text-sm text-white/70" aria-live="polite">
                {visibleEntries.length} of {entries.length} game
                {entries.length === 1 ? "" : "s"}
              </p>
              <p
                className="order-last basis-full items-center gap-1.5 text-sm text-white/70 sm:order-none sm:flex sm:basis-auto"
                title="Sum of the main-story beat time across every entry in your backlog"
              >
                <span className="inline-flex items-center gap-1.5">
                  <Clock className="h-3.5 w-3.5" />
                  {Math.round(totalMainTime).toLocaleString()}h to beat
                </span>
              </p>
              <div className="ml-auto flex items-center gap-2">
                {toolbarStart}
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  aria-pressed={selectionMode}
                  onClick={() =>
                    selectionMode ? endSelection() : setSelectionMode(true)
                  }
                  className={`gap-2 ${selectionMode ? "surface-glow" : ""}`}
                >
                  <ListChecks className="h-4 w-4" />
                  Select
                </Button>
                <IgdbSyncButton />
                {user?.steamId && <SteamSyncButton />}
              </div>
            </div>

            {selectionMode && (
              <BulkActionBar
                selectedCount={selectedEntryRefs.length}
                visibleCount={visibleEntries.length}
                statusOptions={statusOptions}
                isBusy={bulkUpdateStatus.isPending || bulkDelete.isPending}
                onSelectAllVisible={() =>
                  setSelectedIds(
                    new Set(visibleEntries.map((entry) => entry.id)),
                  )
                }
                onClearSelection={() => setSelectedIds(new Set())}
                onSetStatus={(status) => void handleBulkStatus(status)}
                onDelete={() => setPendingDelete(selectedEntryRefs)}
                onDone={endSelection}
              />
            )}

            {entries.length === 0 ? (
              <EmptyState
                title="Your backlog is empty"
                hint="Start by adding your first game!"
              />
            ) : visibleEntries.length === 0 ? (
              <EmptyState
                title="No entries match your filters"
                hint="Try adjusting your filter settings"
              />
            ) : sortBy === "status" ? (
              <DndContext
                sensors={sensors}
                onDragStart={handleDragStart}
                onDragEnd={handleDragEnd}
                onDragCancel={() => setDraggedEntry(null)}
              >
                <div className="flex flex-col gap-4">
                  {groups.map((group) => (
                    <StatusGroupSection
                      key={group.status}
                      status={group.status}
                      items={group.entries}
                      renderItem={renderDraggableEntry}
                      isCollapsed={collapsedGroups.includes(
                        groupKey(group.status),
                      )}
                      onToggle={() => toggleGroup(group.status)}
                    />
                  ))}
                </div>
                {createPortal(
                  <DragOverlay>
                    {draggedEntry && <DragPreview entry={draggedEntry} />}
                  </DragOverlay>,
                  document.body,
                )}
              </DndContext>
            ) : sortBy === "category" ? (
              <DndContext
                sensors={sensors}
                onDragStart={handleDragStart}
                onDragEnd={handleDragEnd}
                onDragCancel={() => setDraggedEntry(null)}
              >
                <div className="flex flex-col gap-4">
                  {categoryGroups.map((group) => (
                    <CategoryGroupSection
                      key={group.label}
                      label={group.label}
                      items={group.entries}
                      renderItem={renderDraggableEntry}
                      color={
                        categoryColors.get(group.label) ?? theme.colors.accent
                      }
                      isCollapsed={collapsedGroups.includes(
                        groupKey(group.label),
                      )}
                      onToggle={() => toggleGroup(group.label)}
                      isDroppable={group.label !== "Uncategorized"}
                    />
                  ))}
                </div>
                {createPortal(
                  <DragOverlay>
                    {draggedEntry && <DragPreview entry={draggedEntry} />}
                  </DragOverlay>,
                  document.body,
                )}
              </DndContext>
            ) : (
              <div className="flex flex-col gap-4">
                {labelGroups.map((group) => (
                  <GroupSection
                    key={group.label}
                    label={group.label}
                    items={group.entries}
                    renderItem={renderEntry}
                    color={theme.colors.accent}
                    isCollapsed={collapsedGroups.includes(
                      groupKey(group.label),
                    )}
                    onToggle={() => toggleGroup(group.label)}
                  />
                ))}
              </div>
            )}
          </div>

          {!isDesktop && (
            <>
              <BottomSheet
                open={isSheetOpen}
                onOpenChange={setIsSheetOpen}
                title="Sort & filter"
                footer={
                  <Button
                    type="button"
                    className="h-11 w-full text-base"
                    onClick={() => setIsSheetOpen(false)}
                  >
                    Show {visibleEntries.length} game
                    {visibleEntries.length === 1 ? "" : "s"}
                  </Button>
                }
              >
                {sidebarPanel}
              </BottomSheet>
            </>
          )}
        </div>

        <Dialog
          open={openEntry !== undefined}
          onOpenChange={(open) => {
            if (!open) setOpenEntryId(null);
          }}
        >
          {openEntry && (
            <Suspense fallback={null}>
              <EntryDetail key={openEntry.id} {...openEntry} />
            </Suspense>
          )}
        </Dialog>

        <AlertDialog
          open={pendingDelete !== null}
          onOpenChange={(open) => {
            if (!open && !bulkDelete.isPending) setPendingDelete(null);
          }}
        >
          <AlertDialogContent className="bg-background border-2 border-red-600">
            <AlertDialogHeader>
              <AlertDialogTitle className="text-xl">
                {pendingDelete?.length === 1
                  ? `Delete "${pendingDelete[0]?.title}"?`
                  : `Delete ${pendingDelete?.length ?? 0} games?`}
              </AlertDialogTitle>
              <AlertDialogDescription className="text-white/70">
                This action cannot be undone. This will permanently delete
                {pendingDelete?.length === 1
                  ? " this backlog entry"
                  : " these backlog entries"}{" "}
                from your collection.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel disabled={bulkDelete.isPending}>
                Cancel
              </AlertDialogCancel>
              <AlertDialogAction
                onClick={(event) => {
                  event.preventDefault();
                  void confirmDelete();
                }}
                disabled={bulkDelete.isPending}
                className="bg-red-600 text-white hover:bg-red-700"
              >
                {bulkDelete.isPending ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Deleting...
                  </>
                ) : (
                  "Delete"
                )}
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </MotionConfig>
    </EntryActionsProvider>
  );
};

const EmptyState = ({ title, hint }: { title: string; hint: string }) => (
  <div className="flex flex-1 items-center justify-center py-16">
    <div className="text-center">
      <h2 className="mb-2 text-2xl font-bold">{title}</h2>
      <p className="text-white/60">{hint}</p>
    </div>
  </div>
);
