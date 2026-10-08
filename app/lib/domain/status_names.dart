/// The five statuses every backlog has, in the order they are listed.
const defaultStatuses = [
  'Not Started',
  'In Progress',
  'Completed',
  'On Hold',
  'Dropped',
];

const statusNameMaxLength = 20;

/// The message for a new custom status name, or '' when the name is fine or
/// still empty. Default statuses are matched exactly, custom ones by their
/// trimmed name.
String statusNameError(String name, List<String> customNames) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.length > statusNameMaxLength) {
    return 'Max $statusNameMaxLength characters';
  }
  if (defaultStatuses.contains(trimmed)) {
    return "That's already a default status";
  }
  if (customNames.contains(trimmed)) {
    return 'You already have a status with that name';
  }
  return '';
}
