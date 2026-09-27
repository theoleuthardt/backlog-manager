"use client";
import { ArrowDownAZ, ArrowUpAZ, RotateCcw } from "lucide-react";
import { Button } from "shadcn_components/ui/button";
import { Checkbox } from "shadcn_components/ui/checkbox";
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "shadcn_components/ui/dropdown-menu";
import { Label } from "shadcn_components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "shadcn_components/ui/select";
import { Slider } from "shadcn_components/ui/slider";
import {
  ToggleGroup,
  ToggleGroupItem,
} from "shadcn_components/ui/toggle-group";
import {
  countActiveFilters,
  EMPTY_FILTERS,
  type EntryFilters,
  type NumericRange,
} from "~/lib/filterEntries";
import {
  isSortOption,
  SORT_OPTIONS,
  type SortDirection,
  type SortOption,
} from "~/lib/sortEntries";

export interface FilterBounds {
  interest: number;
  reviewStars: number;
  playtime: number;
  mainTime: number;
  mainPlusExtraTime: number;
  completionTime: number;
}

interface DashboardSidebarProps {
  sortBy: SortOption;
  direction: SortDirection;
  onSortByChange: (sortBy: SortOption) => void;
  onDirectionChange: (direction: SortDirection) => void;
  filters: EntryFilters;
  onFiltersChange: (filters: EntryFilters) => void;
  platformOptions: string[];
  genreOptions: string[];
  statusOptions: string[];
  categoryOptions: string[];
  bounds: FilterBounds;
}

interface RangeFilterProps {
  label: string;
  unit?: string;
  max: number;
  value: NumericRange;
  onChange: (value: NumericRange) => void;
}

const RangeFilter = ({
  label,
  unit = "",
  max,
  value,
  onChange,
}: RangeFilterProps) => {
  const [low, high] = value ?? [0, max];
  return (
    <div className="space-y-2">
      <Label className="flex justify-between text-sm font-medium">
        <span>{label}</span>
        <span className="text-white/70">
          {value ? `${low}${unit} - ${high}${unit}` : "Any"}
        </span>
      </Label>
      <Slider
        min={0}
        max={max}
        step={1}
        value={[low, high]}
        onValueChange={(next) => {
          const [nextLow = 0, nextHigh = max] = next;
          onChange(
            nextLow === 0 && nextHigh === max ? null : [nextLow, nextHigh],
          );
        }}
        aria-label={label}
      />
    </div>
  );
};

interface MultiSelectFilterProps {
  label: string;
  placeholder: string;
  options: string[];
  selected: readonly string[];
  onChange: (selected: string[]) => void;
}

const MultiSelectFilter = ({
  label,
  placeholder,
  options,
  selected,
  onChange,
}: MultiSelectFilterProps) => (
  <div className="space-y-2">
    <Label className="text-sm font-medium">{label}</Label>
    <DropdownMenu>
      <DropdownMenuTrigger className="w-full cursor-pointer rounded-md border border-white/40 bg-transparent px-3 py-2 text-left text-sm hover:bg-white/10">
        {selected.length > 0 ? `${selected.length} selected` : placeholder}
      </DropdownMenuTrigger>
      <DropdownMenuContent className="max-h-60 w-56 overflow-y-auto">
        {options.map((option) => (
          <DropdownMenuCheckboxItem
            key={option}
            checked={selected.includes(option)}
            onSelect={(event) => event.preventDefault()}
            onCheckedChange={(checked) =>
              onChange(
                checked
                  ? [...selected, option]
                  : selected.filter((value) => value !== option),
              )
            }
          >
            {option}
          </DropdownMenuCheckboxItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  </div>
);

export const DashboardSidebar = ({
  sortBy,
  direction,
  onSortByChange,
  onDirectionChange,
  filters,
  onFiltersChange,
  platformOptions,
  genreOptions,
  statusOptions,
  categoryOptions,
  bounds,
}: DashboardSidebarProps) => {
  const update = (changes: Partial<EntryFilters>) =>
    onFiltersChange({ ...filters, ...changes });
  const activeCount = countActiveFilters(filters);

  return (
    <div className="flex flex-col gap-6">
      <section aria-labelledby="sort-heading" className="space-y-3">
        <h2
          id="sort-heading"
          className="text-xs font-bold tracking-widest text-white/70 uppercase"
        >
          Sort by
        </h2>
        <div className="flex gap-2">
          <Select
            value={sortBy}
            onValueChange={(value) => {
              if (isSortOption(value)) onSortByChange(value);
            }}
          >
            <SelectTrigger className="flex-1" aria-label="Sort by">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {SORT_OPTIONS.map((option) => (
                <SelectItem key={option.value} value={option.value}>
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button
            type="button"
            variant="outline"
            size="icon"
            onClick={() =>
              onDirectionChange(direction === "asc" ? "desc" : "asc")
            }
            aria-label={
              direction === "asc"
                ? "Ascending, switch to descending"
                : "Descending, switch to ascending"
            }
            title={direction === "asc" ? "Ascending" : "Descending"}
          >
            {direction === "asc" ? (
              <ArrowDownAZ className="h-4 w-4" />
            ) : (
              <ArrowUpAZ className="h-4 w-4" />
            )}
          </Button>
        </div>
        <p className="text-xs text-white/60">
          {sortBy === "status"
            ? "Grouped by status - drag a game onto another group to change its status."
            : `Grouped by ${SORT_OPTIONS.find((option) => option.value === sortBy)?.label.toLowerCase() ?? sortBy}.`}
        </p>
      </section>

      <section aria-labelledby="filter-heading" className="space-y-4">
        <div className="flex items-center justify-between">
          <h2
            id="filter-heading"
            className="text-xs font-bold tracking-widest text-white/70 uppercase"
          >
            Filter{activeCount > 0 ? ` (${activeCount})` : ""}
          </h2>
          {activeCount > 0 && (
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="h-7 gap-1 px-2 text-xs"
              onClick={() =>
                onFiltersChange({ ...EMPTY_FILTERS, search: filters.search })
              }
            >
              <RotateCcw className="h-3 w-3" />
              Reset
            </Button>
          )}
        </div>

        <div className="space-y-2">
          <Label className="text-sm font-medium">Platform</Label>
          <ToggleGroup
            type="multiple"
            value={[...filters.platforms]}
            onValueChange={(platforms) => update({ platforms })}
            className="flex flex-wrap justify-start gap-1"
          >
            {platformOptions.map((platform) => (
              <ToggleGroupItem
                key={platform}
                value={platform}
                className="data-[state=on]:bg-primary data-[state=on]:text-primary-foreground h-8 px-2 text-xs"
              >
                {platform}
              </ToggleGroupItem>
            ))}
          </ToggleGroup>
        </div>

        <MultiSelectFilter
          label="Genre"
          placeholder="Select genres"
          options={genreOptions}
          selected={filters.genres}
          onChange={(genres) => update({ genres })}
        />
        <MultiSelectFilter
          label="Status"
          placeholder="Select status"
          options={statusOptions}
          selected={filters.statuses}
          onChange={(statuses) => update({ statuses })}
        />

        {categoryOptions.length > 0 && (
          <MultiSelectFilter
            label="Category"
            placeholder="Select categories"
            options={categoryOptions}
            selected={filters.categories}
            onChange={(categories) => update({ categories })}
          />
        )}

        <div className="flex items-center space-x-2">
          <Checkbox
            id="owned"
            checked={filters.ownedOnly}
            onCheckedChange={(checked) =>
              update({ ownedOnly: checked === true })
            }
            className="border-white"
          />
          <Label htmlFor="owned" className="cursor-pointer text-sm font-medium">
            Owned only
          </Label>
        </div>

        <RangeFilter
          label="Interest"
          max={bounds.interest}
          value={filters.interest}
          onChange={(interest) => update({ interest })}
        />
        <RangeFilter
          label="Review stars"
          max={bounds.reviewStars}
          value={filters.reviewStars}
          onChange={(reviewStars) => update({ reviewStars })}
        />
        <RangeFilter
          label="Playtime"
          unit="h"
          max={bounds.playtime}
          value={filters.playtime}
          onChange={(playtime) => update({ playtime })}
        />
        <RangeFilter
          label="Main story"
          unit="h"
          max={bounds.mainTime}
          value={filters.mainTime}
          onChange={(mainTime) => update({ mainTime })}
        />
        <RangeFilter
          label="Main + extra"
          unit="h"
          max={bounds.mainPlusExtraTime}
          value={filters.mainPlusExtraTime}
          onChange={(mainPlusExtraTime) => update({ mainPlusExtraTime })}
        />
        <RangeFilter
          label="Completionist"
          unit="h"
          max={bounds.completionTime}
          value={filters.completionTime}
          onChange={(completionTime) => update({ completionTime })}
        />
      </section>
    </div>
  );
};
