import 'package:backlog_manager/domain/backups.dart';

/// One snapshot of the Shared Space the server keeps.
class SpaceBackup {
  const SpaceBackup({
    required this.id,
    required this.kind,
    required this.name,
    required this.createdAt,
    required this.entryCount,
    required this.categoryCount,
    required this.createdBy,
  });

  final int id;
  final String kind;
  final String? name;

  /// When the backup was made, in UTC.
  final DateTime createdAt;
  final int entryCount;
  final int categoryCount;

  /// The member who took it; null for an automatic backup.
  final String? createdBy;

  String get title => backupTitle(name: name, kind: kind);

  /// The line under the title: the kind (and who took it) with the content.
  String get detail {
    final by = createdBy == null ? '' : ' by $createdBy';
    return '${backupKindLabel(kind)}$by - '
        '${backupContentSummary(entryCount: entryCount, categoryCount: categoryCount)}';
  }

  String get fileName => 'space-backup-$id.json';
}

/// A restore one member asked for and the other still has to approve.
class RestoreRequest {
  const RestoreRequest({
    required this.id,
    required this.backupId,
    required this.backupName,
    required this.backupCreatedAt,
    required this.requestedBy,
    required this.requestedByMe,
    required this.createdAt,
    required this.expiresAt,
  });

  final int id;
  final int backupId;
  final String? backupName;
  final DateTime backupCreatedAt;
  final String requestedBy;
  final bool requestedByMe;
  final DateTime createdAt;
  final DateTime expiresAt;

  String get _backup => backupName == null
      ? 'the backup from ${backupDateLabel(backupCreatedAt)}'
      : '"$backupName"';

  /// What the banner says: [partner] is the other member, who has to approve
  /// a restore the signed-in member asked for.
  String headline(String partner) => requestedByMe
      ? 'Waiting for $partner to approve restoring $_backup.'
      : '$requestedBy wants to restore $_backup.';

  /// How long the request can still be approved, from [now] in UTC.
  String timeLeft(DateTime now) {
    final left = expiresAt.difference(now);
    if (left.isNegative || left == Duration.zero) return 'expired';
    if (left.inHours >= 1) return '${left.inHours} h left';
    return '${left.inMinutes} min left';
  }
}

/// What asking for a restore did: it ran at once (the member is alone in the
/// space) or it waits for the partner.
class SpaceRestoreOutcome {
  const SpaceRestoreOutcome.restored() : request = null;

  const SpaceRestoreOutcome.waiting(RestoreRequest this.request);

  final RestoreRequest? request;

  bool get isRestored => request == null;
}

/// The backups of the space and the restore waiting for approval, if any.
class SpaceBackups {
  const SpaceBackups({required this.backups, required this.restoreRequest});

  final List<SpaceBackup> backups;
  final RestoreRequest? restoreRequest;
}
