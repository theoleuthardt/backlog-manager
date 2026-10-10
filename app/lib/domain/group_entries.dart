import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/sort_entries.dart';

/// The group of the games that have no category.
const uncategorizedLabel = 'Uncategorized';

class StatusGroup {
  const StatusGroup({required this.status, required this.entries});

  final String status;
  final List<BacklogEntry> entries;
}

/// Splits [entries] into one group per status. Every status in [statusOrder]
/// gets a group even when it has no entries, so the dashboard can still show
/// it as a drag-and-drop target; statuses that only occur on entries (e.g.
/// imported from CSV) are appended after the known ones.
List<StatusGroup> groupEntriesByStatus(
  List<BacklogEntry> entries,
  List<String> statusOrder,
) {
  final groups = <String, List<BacklogEntry>>{
    for (final status in statusOrder) status: [],
  };
  for (final entry in entries) {
    groups.putIfAbsent(entry.status, () => []).add(entry);
  }
  return [
    for (final group in groups.entries)
      StatusGroup(status: group.key, entries: group.value),
  ];
}

class LabelGroup {
  const LabelGroup({required this.label, required this.entries});

  final String label;
  final List<BacklogEntry> entries;
}

String _playtimeBucket(double? playtime) {
  if (playtime == null || playtime == 0) return 'Not played';
  if (playtime < 10) return 'Under 10h';
  if (playtime < 50) return '10-50h';
  if (playtime < 100) return '50-100h';
  return '100h or more';
}

/// Headline an entry falls under for the given sort option. Uses the same key
/// the sort uses (first genre, first platform, ...), so entries that sort next
/// to each other land in the same group.
String groupLabelFor(
  BacklogEntry entry,
  SortOption sortBy, [
  Map<int, String>? categoryByEntryId,
]) {
  switch (sortBy) {
    case SortOption.status:
      return entry.status;
    case SortOption.category:
      return categoryByEntryId?[entry.id] ?? uncategorizedLabel;
    case SortOption.genre:
      return entry.genre.firstOrNull ?? 'No genre';
    case SortOption.platform:
      return entry.platform.firstOrNull ?? 'No platform';
    case SortOption.interest:
      return 'Interest ${entry.interest}/10';
    case SortOption.reviewStars:
      final stars = entry.reviewStars;
      if (stars == null || stars == 0) return 'Unreviewed';
      return '$stars ${stars == 1 ? 'star' : 'stars'}';
    case SortOption.playtime:
      return _playtimeBucket(entry.playtime);
  }
}

/// Groups already-sorted entries under their headlines, keeping the order in
/// which each label first appears (so the sort direction also orders the
/// groups). Matching entries that are not adjacent - e.g. review stars 0 and
/// "no review" - end up in the same group.
List<LabelGroup> groupSortedEntries(
  List<BacklogEntry> sorted,
  SortOption sortBy, [
  Map<int, String>? categoryByEntryId,
]) {
  final groups = <String, List<BacklogEntry>>{};
  for (final entry in sorted) {
    final label = groupLabelFor(entry, sortBy, categoryByEntryId);
    groups.putIfAbsent(label, () => []).add(entry);
  }
  return [
    for (final group in groups.entries)
      LabelGroup(label: group.key, entries: group.value),
  ];
}
