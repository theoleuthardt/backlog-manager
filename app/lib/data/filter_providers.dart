import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/domain/filter_entries.dart';
import 'package:backlog_manager/domain/filter_tokens.dart';
import 'package:backlog_manager/domain/status_names.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The filters of the library for the personal backlog: the search text of the
/// title bar and the filters of the filter bar. They stay while the user moves
/// between screens and start empty again with the next session.
class FiltersNotifier extends Notifier<EntryFilters> {
  @override
  EntryFilters build() {
    ref.watch(sessionGenerationProvider);
    return emptyFilters;
  }

  void setSearch(String value) => state = state.copyWith(search: value);

  void setOwnedOnly(bool value) => state = state.copyWith(ownedOnly: value);

  void setList(FilterField field, List<String> values) {
    state = setListFilter(state, field, values);
  }

  void setRange(FilterField field, NumericRange range) {
    final max = ref.read(filterBoundsProvider).of(field);
    state = setRangeFilter(state, field, range, max);
  }

  void clear(FilterField field) => state = clearFilter(state, field);

  void reset() => state = resetFilters(state);
}

final filtersProvider = NotifierProvider<FiltersNotifier, EntryFilters>(
  FiltersNotifier.new,
);

/// The filters without the selected categories that were deleted since.
final effectiveFiltersProvider = Provider<EntryFilters>((ref) {
  final filters = ref.watch(filtersProvider);
  if (filters.categories.isEmpty) return filters;
  final categories = ref.watch(categoriesProvider(null)).value;
  if (categories == null) return filters;
  return dropMissingCategories(filters, [
    for (final category in categories) category.name,
  ]);
});

/// How many filters are active, for the filter bar and the status bar.
final activeFilterCountProvider = Provider<int>(
  (ref) => countActiveFilters(ref.watch(effectiveFiltersProvider)),
);

/// The values the filter pickers offer.
class FilterOptions {
  const FilterOptions({
    required this.platforms,
    required this.genres,
    required this.statuses,
    required this.categories,
  });

  final List<String> platforms;
  final List<String> genres;

  /// The built-in statuses, the custom ones and any status only entries carry,
  /// in that order.
  final List<String> statuses;
  final List<String> categories;

  List<String> of(FilterField field) {
    return switch (field) {
      FilterField.platform => platforms,
      FilterField.genre => genres,
      FilterField.status => statuses,
      FilterField.category => categories,
      _ => const [],
    };
  }
}

final filterOptionsProvider = Provider<FilterOptions>((ref) {
  final entries = ref.watch(entriesProvider(null)).value ?? const [];
  final custom = ref.watch(customStatusesProvider(null)).value ?? const [];
  final categories = ref.watch(categoriesProvider(null)).value ?? const [];
  return FilterOptions(
    platforms: uniqueSorted(entries.expand((entry) => entry.platform)),
    genres: uniqueSorted(entries.expand((entry) => entry.genre)),
    statuses: <String>{
      ...defaultStatuses,
      for (final status in custom) status.name,
      for (final entry in entries) entry.status,
    }.toList(),
    categories: uniqueSorted([
      for (final category in categories) category.name,
    ]),
  );
});

final filterBoundsProvider = Provider<FilterBounds>((ref) {
  return filterBounds(ref.watch(entriesProvider(null)).value ?? const []);
});
