import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/backlog_scope.dart';
import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/data/group_order_store.dart';
import 'package:backlog_manager/domain/entry_order.dart';
import 'package:backlog_manager/domain/filter_entries.dart';
import 'package:backlog_manager/domain/group_order.dart';
import 'package:backlog_manager/domain/library_groups.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/sort_entries.dart';
import 'package:backlog_manager/features/library/library_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the library shows: the sections plus the numbers of the toolbar.
class LibraryContent {
  const LibraryContent({
    required this.groups,
    required this.total,
    required this.shown,
    required this.hoursToBeat,
  });

  final List<LibraryGroup> groups;
  final int total;
  final int shown;

  /// Main-story hours summed over the whole backlog, not only what is shown.
  final double hoursToBeat;
}

/// The library sections for the personal backlog, or null while the entries
/// are not loaded. The statuses are the built-in ones, the custom ones and any
/// status only entries carry, in that order; the filters of the filter bar
/// and the search text narrow the entries. Only the sort option, its
/// direction and the orders of the groups ([LibraryViewState.entryOrders])
/// are watched from the view, so folding a group away or paging does not sort
/// the entries again.
final libraryContentProvider = Provider<LibraryContent?>((ref) {
  final entries = ref
      .watch(entriesProvider(ref.watch(backlogScopeProvider)))
      .value;
  if (entries == null) return null;
  final (sortBy, direction) = ref.watch(
    libraryViewProvider.select((view) => (view.sortBy, view.direction)),
  );
  final filters = ref.watch(effectiveFiltersProvider);
  final statusOrder = ref.watch(
    filterOptionsProvider.select((options) => options.statuses),
  );

  final groupOrder = ref.watch(groupOrderProvider);
  final entryOrders = ref.watch(
    libraryViewProvider.select((view) => view.entryOrders),
  );

  var categoriesByEntry = const <int, List<Category>>{};
  if (sortBy == SortOption.category || filters.categories.isNotEmpty) {
    categoriesByEntry =
        ref
            .watch(entryCategoriesProvider(ref.watch(backlogScopeProvider)))
            .value ??
        const {};
  }
  Map<int, String>? firstCategory;
  var categoryNames = const <String>[];
  var categoryColors = const <String, String>{};
  if (sortBy == SortOption.category) {
    firstCategory = {
      for (final item in categoriesByEntry.entries)
        if (item.value.isNotEmpty) item.key: item.value.first.name,
    };
    final categories =
        ref.watch(categoriesProvider(ref.watch(backlogScopeProvider))).value ??
        <Category>[];
    categoryNames = [for (final category in categories) category.name];
    categoryColors = {
      for (final category in categories) category.name: category.color,
    };
  }

  final visible = filterEntries(entries, filters, {
    for (final item in categoriesByEntry.entries)
      item.key: [for (final category in item.value) category.name],
  });
  var hours = 0.0;
  for (final entry in entries) {
    hours += entry.timeToBeat ?? 0;
  }
  final groups = applyGroupOrder(
    buildLibraryGroups(
      entries: visible,
      config: SortConfig(
        sortBy: sortBy,
        direction: direction,
        statusOrder: statusOrder,
        categoryByEntryId: firstCategory,
      ),
      statusFilter: filters.statuses.toSet(),
      categoryNames: categoryNames,
      categoryColors: categoryColors,
    ),
    groupOrder,
  );
  return LibraryContent(
    groups: [
      for (final group in groups)
        if (entryOrders[group.key] case final order?)
          LibraryGroup(
            key: group.key,
            label: group.label,
            entries: orderEntries(group.entries, order),
            status: group.status,
            color: group.color,
            droppable: group.droppable,
          )
        else
          group,
    ],
    total: entries.length,
    shown: visible.length,
    hoursToBeat: hours,
  );
});
