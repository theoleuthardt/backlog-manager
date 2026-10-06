import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/text_order.dart';

const categoryNameMaxLength = 100;

const categoryColors = [
  '#38bdf8',
  '#4ade80',
  '#fbbf24',
  '#f87171',
  '#c084fc',
  '#fb923c',
  '#2dd4bf',
  '#f472b6',
];

String nextCategoryColor(int existingCount) =>
    categoryColors[existingCount % categoryColors.length];

/// Validation message for a new or renamed category, or '' when the name is
/// fine. Names double as the filter key, so duplicates are rejected
/// case-insensitively; [otherNames] must exclude the category being renamed.
String categoryNameError(String name, List<String> otherNames) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.length > categoryNameMaxLength) {
    return 'Max $categoryNameMaxLength characters';
  }
  final lower = trimmed.toLowerCase();
  if (otherNames.any((other) => other.trim().toLowerCase() == lower)) {
    return 'You already have a category with that name';
  }
  return '';
}

/// A new list of the categories ordered alphabetically by name, ignoring case
/// and accents; names that only differ in those keep their input order.
List<Category> sortCategoriesByName(List<Category> categories) {
  return stableSorted(categories, (a, b) => compareBase(a.name, b.name));
}
