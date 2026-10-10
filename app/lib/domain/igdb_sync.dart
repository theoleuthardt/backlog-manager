/// What the sheet of the IGDB sync says about the games it would look up.
String pendingLabel(int? count, {required bool failed}) {
  if (failed) return 'Could not count the games to sync.';
  if (count == null) return 'Counting games...';
  if (count == 0) return 'Every game already has IGDB data.';
  return '$count ${count == 1 ? 'game' : 'games'} will be looked up.';
}

/// The toast after a finished sync.
String syncResultMessage(int updated) {
  if (updated == 0) return 'No IGDB data could be added';
  return 'Updated $updated ${updated == 1 ? 'game' : 'games'} with IGDB data';
}

/// The line under the progress bar; [processed] and [total] are null until the
/// first progress message arrives.
String progressLabel(int? processed, int? total) {
  if (processed == null || total == null) return 'Starting...';
  return 'Looking up games $processed/$total';
}

/// How much of the bar is filled, between 0 and 1.
double syncFraction(int? processed, int? total) {
  if (processed == null || total == null || total <= 0) return 0;
  return processed / total;
}
