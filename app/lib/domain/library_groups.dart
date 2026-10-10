import 'package:backlog_manager/domain/group_entries.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/sort_entries.dart';
import 'package:backlog_manager/domain/text_order.dart';

/// One section of the library: a headline and its games. [status] is set when
/// the library is sorted by status, where a group is also a drop target.
class LibraryGroup {
  const LibraryGroup({
    required this.key,
    required this.label,
    required this.entries,
    this.status,
    this.droppable = false,
  });

  /// Identifies the group across sort options, for the collapsed state.
  final String key;
  final String label;
  final List<BacklogEntry> entries;
  final String? status;

  /// Whether a game can be dropped on the group: the status groups of the
  /// status sort and the categories of the category sort, not the games
  /// without a category.
  final bool droppable;
}

/// The sections of the library for the (already filtered) [entries].
/// Sorted by status there is one group per status, empty ones too, in the
/// order of [SortConfig.statusOrder] (reversed for a descending sort); a
/// non-empty [statusFilter] limits the groups to those statuses. Sorted by
/// category the categories without a game ([categoryNames]) follow the others,
/// ordered by name. Every other option groups like [groupSortedEntries].
List<LibraryGroup> buildLibraryGroups({
  required List<BacklogEntry> entries,
  required SortConfig config,
  Set<String>? statusFilter,
  List<String> categoryNames = const [],
}) {
  final sorted = sortEntries(entries, config);
  final sortBy = config.sortBy;

  if (sortBy == SortOption.status) {
    final order = config.direction == SortDirection.asc
        ? config.statusOrder
        : config.statusOrder.reversed.toList();
    final filtered = statusFilter == null || statusFilter.isEmpty
        ? null
        : statusFilter;
    return [
      for (final group in groupEntriesByStatus(sorted, order))
        if (filtered == null || filtered.contains(group.status))
          LibraryGroup(
            key: 'status:${group.status}',
            label: group.status,
            entries: group.entries,
            status: group.status,
            droppable: true,
          ),
    ];
  }

  final groups = [
    for (final group in groupSortedEntries(
      sorted,
      sortBy,
      config.categoryByEntryId,
    ))
      LibraryGroup(
        key: '${sortBy.value}:${group.label}',
        label: group.label,
        entries: group.entries,
        droppable:
            sortBy == SortOption.category && group.label != uncategorizedLabel,
      ),
  ];

  if (sortBy != SortOption.category) return groups;
  final present = {for (final group in groups) group.label};
  final empty = categoryNames.where((name) => !present.contains(name)).toList()
    ..sort(compareText);
  return [
    ...groups,
    for (final name in empty)
      LibraryGroup(
        key: 'category:$name',
        label: name,
        entries: const [],
        droppable: true,
      ),
  ];
}
