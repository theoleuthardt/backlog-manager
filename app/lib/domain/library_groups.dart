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
    this.color,
    this.droppable = false,
  });

  /// Identifies the group across sort options, for the collapsed state.
  final String key;
  final String label;
  final List<BacklogEntry> entries;
  final String? status;

  /// The hex colour of the category of a group of the category sort, for its
  /// dot; null for every other group.
  final String? color;

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
/// ordered by name, and a group has the colour of its category from
/// [categoryColors] (by name). Every other option groups like
/// [groupSortedEntries].
List<LibraryGroup> buildLibraryGroups({
  required List<BacklogEntry> entries,
  required SortConfig config,
  Set<String>? statusFilter,
  List<String> categoryNames = const [],
  Map<String, String> categoryColors = const {},
  Map<int, List<String>> entryCategories = const {},
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

  final grouped = sortBy == SortOption.category && entryCategories.isNotEmpty
      ? _byEveryCategory(entries, entryCategories, config.direction)
      : groupSortedEntries(sorted, sortBy, config.categoryByEntryId);
  final groups = [
    for (final group in grouped)
      LibraryGroup(
        key: '${sortBy.value}:${group.label}',
        label: group.label,
        entries: group.entries,
        color: sortBy == SortOption.category
            ? categoryColors[group.label]
            : null,
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
        color: categoryColors[name],
        droppable: true,
      ),
  ];
}

/// The groups of the category sort with every game in each of its
/// [categories] (by entry id), the categories by name in [direction] and the
/// games without one last; the games of a group by title.
List<LabelGroup> _byEveryCategory(
  List<BacklogEntry> entries,
  Map<int, List<String>> categories,
  SortDirection direction,
) {
  final byName = <String, List<BacklogEntry>>{};
  final without = <BacklogEntry>[];
  for (final entry in entries) {
    final names = categories[entry.id] ?? const <String>[];
    if (names.isEmpty) without.add(entry);
    for (final name in names.toSet()) {
      (byName[name] ??= []).add(entry);
    }
  }
  int byTitle(BacklogEntry a, BacklogEntry b) => compareText(a.title, b.title);
  final names = byName.keys.toList()..sort(compareText);
  return [
    for (final name in direction == SortDirection.asc ? names : names.reversed)
      LabelGroup(label: name, entries: stableSorted(byName[name]!, byTitle)),
    if (without.isNotEmpty)
      LabelGroup(
        label: uncategorizedLabel,
        entries: stableSorted(without, byTitle),
      ),
  ];
}
