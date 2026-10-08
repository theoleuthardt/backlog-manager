import 'package:backlog_manager/domain/filter_entries.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/text_order.dart';

/// The filters the filter bar offers, in the order of its "Add filter" menu.
/// Owned only is a switch of its own and the search text lives in the title
/// bar, so neither is a field.
enum FilterField {
  platform('Platform'),
  genre('Genre'),
  status('Status'),
  category('Category'),
  interest('Interest'),
  reviewStars('Review stars'),
  playtime('Playtime', unit: ' h'),
  mainTime('Main story', unit: ' h'),
  mainPlusExtraTime('Main + extra', unit: ' h'),
  completionTime('Completionist', unit: ' h');

  const FilterField(this.label, {this.unit = ''});

  final String label;

  /// Appended to the numbers of a range in its token.
  final String unit;

  bool get isRange => index >= FilterField.interest.index;
}

/// One active filter as the bar shows it: the field and its value text.
class FilterToken {
  const FilterToken(this.field, this.value);

  final FilterField field;
  final String value;
}

/// The upper end of every range slider.
class FilterBounds {
  const FilterBounds({
    required this.interest,
    required this.reviewStars,
    required this.playtime,
    required this.mainTime,
    required this.mainPlusExtraTime,
    required this.completionTime,
  });

  final int interest;
  final int reviewStars;
  final int playtime;
  final int mainTime;
  final int mainPlusExtraTime;
  final int completionTime;

  int of(FilterField field) {
    return switch (field) {
      FilterField.interest => interest,
      FilterField.reviewStars => reviewStars,
      FilterField.playtime => playtime,
      FilterField.mainTime => mainTime,
      FilterField.mainPlusExtraTime => mainPlusExtraTime,
      FilterField.completionTime => completionTime,
      _ => throw ArgumentError.value(field, 'field', 'is not a range'),
    };
  }
}

const _maxReviewStars = 10;
const _minimumHours = 10;

/// The slider bounds of [entries]: 10 for interest and review stars, the
/// largest value of the data rounded up (at least 10 hours) for the times.
FilterBounds filterBounds(List<BacklogEntry> entries) {
  int largest(double? Function(BacklogEntry entry) pick) {
    var max = 0.0;
    for (final entry in entries) {
      final value = pick(entry) ?? 0;
      if (value > max) max = value;
    }
    final rounded = max.ceil();
    return rounded < _minimumHours ? _minimumHours : rounded;
  }

  return FilterBounds(
    interest: 10,
    reviewStars: _maxReviewStars,
    playtime: largest((entry) => entry.playtime),
    mainTime: largest((entry) => entry.mainTime),
    mainPlusExtraTime: largest((entry) => entry.mainPlusExtraTime),
    completionTime: largest((entry) => entry.completionTime),
  );
}

String _number(num value) {
  return value == value.truncate() ? value.truncate().toString() : '$value';
}

NumericRange _rangeOf(EntryFilters filters, FilterField field) {
  return switch (field) {
    FilterField.interest => filters.interest,
    FilterField.reviewStars => filters.reviewStars,
    FilterField.playtime => filters.playtime,
    FilterField.mainTime => filters.mainTime,
    FilterField.mainPlusExtraTime => filters.mainPlusExtraTime,
    FilterField.completionTime => filters.completionTime,
    _ => null,
  };
}

List<String> _listOf(EntryFilters filters, FilterField field) {
  return switch (field) {
    FilterField.platform => filters.platforms,
    FilterField.genre => filters.genres,
    FilterField.status => filters.statuses,
    FilterField.category => filters.categories,
    _ => const [],
  };
}

/// The value of [field] in [filters]: the selected values of a list filter or
/// the range of a range filter; empty when the filter is not active.
List<String> listValues(EntryFilters filters, FilterField field) =>
    _listOf(filters, field);

NumericRange rangeValue(EntryFilters filters, FilterField field) =>
    _rangeOf(filters, field);

/// The active filters of [filters], one token each, in the order of the
/// fields.
List<FilterToken> filterTokens(EntryFilters filters) {
  final tokens = <FilterToken>[];
  for (final field in FilterField.values) {
    if (field.isRange) {
      final range = _rangeOf(filters, field);
      if (range != null) {
        final (low, high) = range;
        tokens.add(
          FilterToken(
            field,
            '${_number(low)} to ${_number(high)}${field.unit}',
          ),
        );
      }
    } else {
      final values = _listOf(filters, field);
      if (values.isNotEmpty) tokens.add(FilterToken(field, values.join(', ')));
    }
  }
  return tokens;
}

/// [filters] with the list filter of [field] set to [values]; no values
/// removes the filter.
EntryFilters setListFilter(
  EntryFilters filters,
  FilterField field,
  List<String> values,
) {
  return switch (field) {
    FilterField.platform => filters.copyWith(platforms: values),
    FilterField.genre => filters.copyWith(genres: values),
    FilterField.status => filters.copyWith(statuses: values),
    FilterField.category => filters.copyWith(categories: values),
    _ => throw ArgumentError.value(field, 'field', 'is not a list'),
  };
}

/// [filters] with the range filter of [field] set to [range]. A range that
/// covers the whole slider (0 to [max]) is no filter: a range is only active
/// once it was changed, so entries beyond the visible bounds are not hidden by
/// an untouched filter.
EntryFilters setRangeFilter(
  EntryFilters filters,
  FilterField field,
  NumericRange range,
  num max,
) {
  final value = range == null || (range.$1 == 0 && range.$2 == max)
      ? null
      : range;
  return switch (field) {
    FilterField.interest => filters.copyWith(interest: value),
    FilterField.reviewStars => filters.copyWith(reviewStars: value),
    FilterField.playtime => filters.copyWith(playtime: value),
    FilterField.mainTime => filters.copyWith(mainTime: value),
    FilterField.mainPlusExtraTime => filters.copyWith(mainPlusExtraTime: value),
    FilterField.completionTime => filters.copyWith(completionTime: value),
    _ => throw ArgumentError.value(field, 'field', 'is not a range'),
  };
}

EntryFilters clearFilter(EntryFilters filters, FilterField field) {
  return field.isRange
      ? setRangeFilter(filters, field, null, 0)
      : setListFilter(filters, field, const []);
}

/// No filters at all, but the search text stays.
EntryFilters resetFilters(EntryFilters filters) {
  return emptyFilters.copyWith(search: filters.search);
}

/// [filters] without the selected categories that are not in [available]
/// (deleted or renamed ones); the same instance when none is dropped.
EntryFilters dropMissingCategories(
  EntryFilters filters,
  Iterable<String> available,
) {
  final names = available.toSet();
  final kept = [
    for (final name in filters.categories)
      if (names.contains(name)) name,
  ];
  return kept.length == filters.categories.length
      ? filters
      : filters.copyWith(categories: kept);
}

/// Every value once, sorted like the web client.
List<String> uniqueSorted(Iterable<String> values) {
  return values.toSet().toList()..sort(compareText);
}
