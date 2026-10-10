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

/// The time the server sends for a backup: UTC, but without a zone, so it is
/// read as local time by the JSON parser. This keeps the numbers and says UTC.
DateTime serverTimeAsUtc(DateTime parsed) {
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "9 Oct 2026, 08:07" in the time zone of the user; [toLocal] false keeps UTC
/// (for tests).
String backupDateLabel(DateTime createdAtUtc, {bool toLocal = true}) {
  final date = toLocal ? createdAtUtc.toLocal() : createdAtUtc;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.day} ${_months[date.month - 1]} ${date.year}, '
      '${two(date.hour)}:${two(date.minute)}';
}

/// One snapshot of the backlog the server keeps.
class Backup {
  const Backup({
    required this.id,
    required this.kind,
    required this.name,
    required this.createdAt,
    required this.entryCount,
    required this.categoryCount,
  });

  final int id;
  final String kind;
  final String? name;

  /// When the backup was made, in UTC.
  final DateTime createdAt;
  final int entryCount;
  final int categoryCount;

  String get title => backupTitle(name: name, kind: kind);

  String get summary => backupContentSummary(
    entryCount: entryCount,
    categoryCount: categoryCount,
  );

  /// The line under the title: the content, with the kind in front when a name
  /// replaced it as the title.
  String get detail =>
      name == null ? summary : '${backupKindLabel(kind)} - $summary';

  String get fileName => 'backlog-backup-$id.json';
}

/// What a restore brought back.
class RestoreResult {
  const RestoreResult({
    required this.entryCount,
    required this.categoryCount,
    this.safetyBackupId,
  });

  final int entryCount;
  final int categoryCount;

  /// The backup of the state before the restore, if one was made.
  final int? safetyBackupId;

  String get message {
    final content = backupContentSummary(
      entryCount: entryCount,
      categoryCount: categoryCount,
    );
    return 'Restored $content.'
        '${safetyBackupId == null ? '' : ' Your previous state was saved as a backup.'}';
  }
}
