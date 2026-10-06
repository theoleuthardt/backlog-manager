const _kindLabels = {
  'auto': 'Automatic',
  'manual': 'Manual',
  'pre-restore': 'Before a restore',
  'pre-delete': 'Before deleting all games',
  'pre-import': 'Before a CSV import',
};

const maxBackupNameLength = 60;

String backupKindLabel(String kind) => _kindLabels[kind] ?? kind;

String _plural(int count, String singular, String pluralForm) =>
    '$count ${count == 1 ? singular : pluralForm}';

String backupContentSummary({
  required int entryCount,
  required int categoryCount,
}) {
  return '${_plural(entryCount, 'game', 'games')}, '
      '${_plural(categoryCount, 'category', 'categories')}';
}

String backupTitle({required String? name, required String kind}) =>
    name ?? backupKindLabel(kind);

/// The name to store for a backup: trimmed, or null for a blank input so the
/// label is cleared.
String? normalizeBackupName(String input) {
  final trimmed = input.trim();
  return trimmed.isEmpty ? null : trimmed;
}
