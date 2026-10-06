import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/text_order.dart';

enum SortOption {
  status('status', 'Status'),
  category('category', 'Category'),
  genre('genre', 'Genre'),
  playtime('playtime', 'Playtime'),
  platform('platform', 'Platform'),
  interest('interest', 'Interest level'),
  reviewStars('review_stars', 'Review stars');

  const SortOption(this.value, this.label);

  /// The identifier stored in the account settings and used by the API.
  final String value;
  final String label;
}

enum SortDirection { asc, desc }

const defaultSort = SortOption.status;

/// The option with the stored identifier [value], or null for an unknown one.
SortOption? parseSortOption(String value) {
  for (final option in SortOption.values) {
    if (option.value == value) return option;
  }
  return null;
}

SortDirection defaultDirectionFor(SortOption sortBy) {
  return switch (sortBy) {
    SortOption.playtime ||
    SortOption.interest ||
    SortOption.reviewStars => SortDirection.desc,
    _ => SortDirection.asc,
  };
}

class SortConfig {
  const SortConfig({
    required this.sortBy,
    required this.direction,
    required this.statusOrder,
    this.categoryByEntryId,
  });

  final SortOption sortBy;
  final SortDirection direction;
  final List<String> statusOrder;
  final Map<int, String>? categoryByEntryId;
}

Object? _keyFor(BacklogEntry entry, SortConfig config) {
  switch (config.sortBy) {
    case SortOption.status:
      final index = config.statusOrder.indexOf(entry.status);
      return index == -1 ? config.statusOrder.length : index;
    case SortOption.category:
      return config.categoryByEntryId?[entry.id];
    case SortOption.genre:
      return entry.genre.firstOrNull;
    case SortOption.platform:
      return entry.platform.firstOrNull;
    case SortOption.playtime:
      return entry.playtime;
    case SortOption.interest:
      return entry.interest;
    case SortOption.reviewStars:
      return entry.reviewStars == 0 ? null : entry.reviewStars;
  }
}

int _compareKeys(Object a, Object b) {
  if (a is num && b is num) return a.compareTo(b);
  return compareText(a.toString(), b.toString());
}

/// Returns a sorted copy of [entries]. Entries missing the sort key (no
/// playtime, no genre, uncategorized, ...) always sort last, whichever
/// direction is chosen; ties fall back to the title so the order is stable and
/// predictable.
List<BacklogEntry> sortEntries(List<BacklogEntry> entries, SortConfig config) {
  final sign = config.direction == SortDirection.asc ? 1 : -1;
  return [...entries]..sort((a, b) {
    final keyA = _keyFor(a, config);
    final keyB = _keyFor(b, config);
    if (keyA == null && keyB != null) return 1;
    if (keyA != null && keyB == null) return -1;
    if (keyA != null && keyB != null) {
      final result = _compareKeys(keyA, keyB);
      if (result != 0) return result * sign;
    }
    return compareText(a.title, b.title);
  });
}
