String _games(int count) => count == 1 ? '1 game' : '$count games';

/// The toast after moving the selected games to [status]: how many moved and,
/// when some did not, how many failed.
String bulkStatusMessage({
  required int succeeded,
  required int failed,
  required String status,
}) {
  if (failed > 0) return 'Moved $succeeded to $status, $failed failed';
  return 'Moved ${_games(succeeded)} to $status';
}

/// The toast after deleting games; a single game is named by [singleTitle].
String bulkDeleteMessage({
  required int succeeded,
  required int failed,
  String? singleTitle,
}) {
  if (failed > 0) return 'Deleted $succeeded, $failed failed';
  if (singleTitle != null) return '"$singleTitle" deleted';
  return 'Deleted $succeeded games';
}

/// The toast after adding a category to, or removing it from, many games.
String bulkCategoryMessage({
  required bool added,
  required String category,
  required int succeeded,
  required int failed,
}) {
  final verb = added ? 'Added' : 'Removed';
  final preposition = added ? 'to' : 'from';
  if (failed > 0) {
    return '$verb $succeeded $preposition "$category", $failed failed';
  }
  return '$verb ${_games(succeeded)} $preposition "$category"';
}

/// The title of the confirmation before deleting the games with [titles].
String deleteTitle(List<String> titles) {
  if (titles.length == 1) return 'Delete "${titles.single}"?';
  return 'Delete ${titles.length} games?';
}

String deleteDescription(int count) {
  final what = count == 1 ? 'this backlog entry' : 'these backlog entries';
  return 'This action cannot be undone. This will permanently delete $what '
      'from your collection.';
}
