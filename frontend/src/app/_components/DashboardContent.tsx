"use client";
import React, { useMemo, useState } from "react";
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
import { ChevronsLeft, Loader2, SlidersHorizontal } from "lucide-react";
import { toast } from "sonner";
import { Button } from "shadcn_components/ui/button";
import { BacklogEntry } from "components/BacklogEntry";
import { BottomSheet } from "components/BottomSheet";
import {
  DashboardSidebar,
  type FilterBounds,
} from "components/DashboardSidebar";
import { DraggableEntry } from "components/DraggableEntry";
import { DragPreview } from "components/DragPreview";
import { GroupSection } from "components/GroupSection";
import { SteamSyncButton } from "components/SteamSyncButton";
import { StatusGroupSection } from "components/StatusGroupSection";
import { useAuth } from "~/app/context/AuthContext";
import { useDashboard } from "~/app/context/DashboardContext";
import { useTheme } from "~/app/context/ThemeContext";
import {
  useBacklogEntries,
  useCategories,
  useCustomStatuses,
  useEntryCategories,
  useMoveEntryToStatus,
} from "~/hooks/useBacklog";
import { useMediaQuery } from "~/hooks/useMediaQuery";
import { DEFAULT_STATUSES, type BacklogEntryData } from "~/lib/api/backlog";
import {
  countActiveFilters,
  EMPTY_FILTERS,
  filterEntries,
  type EntryFilters,
} from "~/lib/filterEntries";
import { groupEntriesByStatus, groupSortedEntries } from "~/lib/groupEntries";
import {
  DEFAULT_SORT,
  defaultDirectionFor,
  isSortOption,
  sortEntries,
  type SortDirection,
  type SortOption,
} from "~/lib/sortEntries";

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

export const DashboardContent = () => {
  const { user } = useAuth();
  const { searchQuery } = useDashboard();
  const { theme } = useTheme();
  const { data: backlogData, isLoading, error } = useBacklogEntries();
  const { data: customStatuses = [] } = useCustomStatuses();
  const moveEntry = useMoveEntryToStatus();

  const isDesktop = useMediaQuery("(min-width: 1024px)");
  const [sidebarToggle, setSidebarToggle] = useState<boolean | null>(null);
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const isSidebarOpen = sidebarToggle ?? isDesktop;

  const [selectedFilters, setFilters] = useState<EntryFilters>(EMPTY_FILTERS);
  const [sortOverride, setSortOverride] = useState<SortOption | null>(null);
  const [directionOverride, setDirectionOverride] =
    useState<SortDirection | null>(null);
  const [collapsedGroups, setCollapsedGroups] = useState<string[]>([]);
  const [draggedEntry, setDraggedEntry] = useState<BacklogEntryData | null>(
    null,
  );

  const userDefaultSort =
    user && isSortOption(user.defaultSort) ? user.defaultSort : DEFAULT_SORT;
  const sortBy = sortOverride ?? userDefaultSort;
  const direction = directionOverride ?? defaultDirectionFor(sortBy);

  const entries = useMemo(() => backlogData ?? [], [backlogData]);

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
      reviewStars: 5,
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

  const sensors = useSensors(
    useSensor(MouseSensor, { activationConstraint: { distance: 8 } }),
    useSensor(TouchSensor, {
      activationConstraint: { delay: 250, tolerance: 8 },
    }),
  );

  const changeStatus = (entry: BacklogEntryData, status: string) => {
    const previousStatus = entry.status;
    moveEntry.mutate(
      { entryId: entry.id, status },
      {
        onSuccess: () =>
          toast.success(`Moved "${entry.title}" to ${status}`, {
            action: {
              label: "Undo",
              onClick: () =>
                moveEntry.mutate({ entryId: entry.id, status: previousStatus }),
            },
          }),
        onError: (moveError) =>
          toast.error(
            moveError instanceof Error
              ? moveError.message
              : "Failed to change status",
          ),
      },
    );
  };

  const handleDragStart = (event: DragStartEvent) => {
    setDraggedEntry(
      entries.find((entry) => entry.id === event.active.id) ?? null,
    );
  };

  const handleDragEnd = (event: DragEndEvent) => {
    setDraggedEntry(null);
    const entry = entries.find((candidate) => candidate.id === event.active.id);
    const targetStatus = event.over?.id;
    if (!entry || typeof targetStatus !== "string") return;
    if (targetStatus !== entry.status) changeStatus(entry, targetStatus);
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

  return (
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
            {user?.steamId && <SteamSyncButton className="ml-auto" />}
          </div>

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
                    count={group.entries.length}
                    isCollapsed={collapsedGroups.includes(
                      groupKey(group.status),
                    )}
                    onToggle={() => toggleGroup(group.status)}
                  >
                    {group.entries.map((entry) => (
                      <DraggableEntry key={entry.id} entryId={entry.id}>
                        {renderEntry(entry)}
                      </DraggableEntry>
                    ))}
                  </StatusGroupSection>
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
                  count={group.entries.length}
                  color={
                    (sortBy === "category"
                      ? categoryColors.get(group.label)
                      : undefined) ?? theme.colors.accent
                  }
                  isCollapsed={collapsedGroups.includes(groupKey(group.label))}
                  onToggle={() => toggleGroup(group.label)}
                >
                  {group.entries.map(renderEntry)}
                </GroupSection>
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
            </BottomSheet>
          </>
        )}
      </div>
    </MotionConfig>
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
