/// The status of a game the user does not own (a wishlist game). It goes with
/// the owned flag: moving a game to it marks the game as not owned, moving it
/// out marks it as owned.
const notOwnedStatus = 'Not Owned';

/// The six statuses every backlog has, in the order they are listed.
const defaultStatuses = [
  'Not Started',
  'In Progress',
  'Completed',
  'On Hold',
  'Dropped',
  notOwnedStatus,
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
