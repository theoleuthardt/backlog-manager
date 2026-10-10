import 'package:backlog_manager/domain/models.dart';

/// Inclusive `(min, max)` bounds; null means "no restriction" - a range is
/// only active once the user has moved its slider, so entries outside the
/// visible slider bounds (e.g. a 900h playtime) are never hidden by an
/// untouched filter.
typedef NumericRange = (num, num)?;

class EntryFilters {
  const EntryFilters({
    this.search = '',
    this.platforms = const [],
    this.genres = const [],
    this.statuses = const [],
    this.categories = const [],
    this.ownedOnly = false,
    this.interest,
    this.reviewStars,
    this.playtime,
    this.mainTime,
    this.mainPlusExtraTime,
    this.completionTime,
  });

  final String search;
  final List<String> platforms;
  final List<String> genres;
  final List<String> statuses;
  final List<String> categories;
  final bool ownedOnly;
  final NumericRange interest;
  final NumericRange reviewStars;
  final NumericRange playtime;
  final NumericRange mainTime;
  final NumericRange mainPlusExtraTime;
  final NumericRange completionTime;

  /// These filters with the given fields replaced; a range is cleared by
  /// passing null.
  EntryFilters copyWith({
    String? search,
    List<String>? platforms,
    List<String>? genres,
    List<String>? statuses,
    List<String>? categories,
    bool? ownedOnly,
    Object? interest = _keep,
    Object? reviewStars = _keep,
    Object? playtime = _keep,
    Object? mainTime = _keep,
    Object? mainPlusExtraTime = _keep,
    Object? completionTime = _keep,
  }) {
    NumericRange range(Object? value, NumericRange current) =>
        identical(value, _keep) ? current : value as NumericRange;
    return EntryFilters(
      search: search ?? this.search,
      platforms: platforms ?? this.platforms,
      genres: genres ?? this.genres,
      statuses: statuses ?? this.statuses,
      categories: categories ?? this.categories,
      ownedOnly: ownedOnly ?? this.ownedOnly,
      interest: range(interest, this.interest),
      reviewStars: range(reviewStars, this.reviewStars),
      playtime: range(playtime, this.playtime),
      mainTime: range(mainTime, this.mainTime),
      mainPlusExtraTime: range(mainPlusExtraTime, this.mainPlusExtraTime),
      completionTime: range(completionTime, this.completionTime),
    );
  }

  List<(NumericRange, num?)> _rangesFor(BacklogEntry entry) => [
    (interest, entry.interest),
    (reviewStars, entry.reviewStars == 0 ? null : entry.reviewStars),
    (playtime, entry.playtime),
    (mainTime, entry.mainTime),
    (mainPlusExtraTime, entry.mainPlusExtraTime),
    (completionTime, entry.completionTime),
  ];
}

const _keep = Object();

const emptyFilters = EntryFilters();

bool _withinRange(num? value, NumericRange range) {
  if (range == null || value == null) return true;
  return value >= range.$1 && value <= range.$2;
}

bool _sharesAny(List<String> values, List<String> selected) =>
    values.any(selected.contains);

/// The entries that pass every active filter; [categoriesByEntryId] maps an
/// entry to the names of its categories.
List<BacklogEntry> filterEntries(
  List<BacklogEntry> entries,
  EntryFilters filters, [
  Map<int, List<String>> categoriesByEntryId = const {},
]) {
  final search = filters.search.trim().toLowerCase();
  return entries.where((entry) {
    if (search.isNotEmpty && !entry.title.toLowerCase().contains(search)) {
      return false;
    }
    if (filters.platforms.isNotEmpty &&
        !_sharesAny(entry.platform, filters.platforms)) {
      return false;
    }
    if (filters.genres.isNotEmpty && !_sharesAny(entry.genre, filters.genres)) {
      return false;
    }
    if (filters.statuses.isNotEmpty &&
        !filters.statuses.contains(entry.status)) {
      return false;
    }
    if (filters.categories.isNotEmpty &&
        !_sharesAny(
          categoriesByEntryId[entry.id] ?? const [],
          filters.categories,
        )) {
      return false;
    }
    if (filters.ownedOnly && !entry.owned) return false;
    return filters._rangesFor(entry).every((r) => _withinRange(r.$2, r.$1));
  }).toList();
}

/// Number of active filter groups, shown as a badge on the filter toggle. The
/// search text is excluded because it has its own always visible input.
int countActiveFilters(EntryFilters filters) {
  final lists = [
    filters.platforms,
    filters.genres,
    filters.statuses,
    filters.categories,
  ];
  final ranges = [
    filters.interest,
    filters.reviewStars,
    filters.playtime,
    filters.mainTime,
    filters.mainPlusExtraTime,
    filters.completionTime,
  ];
  return lists.where((list) => list.isNotEmpty).length +
      ranges.where((range) => range != null).length +
      (filters.ownedOnly ? 1 : 0);
}
