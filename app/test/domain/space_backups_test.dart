import 'package:backlog_manager/domain/space_backups.dart';
import 'package:flutter_test/flutter_test.dart';

SpaceBackup backup({String kind = 'manual', String? name, String? by}) {
  return SpaceBackup(
    id: 4,
    kind: kind,
    name: name,
    createdAt: DateTime.utc(2026, 10, 19, 8, 30),
    entryCount: 12,
    categoryCount: 2,
    createdBy: by,
  );
}

RestoreRequest request({bool mine = false, DateTime? expires}) {
  return RestoreRequest(
    id: 7,
    backupId: 4,
    backupName: 'Before the sale',
    backupCreatedAt: DateTime.utc(2026, 10, 19, 8, 30),
    requestedBy: 'Alex',
    requestedByMe: mine,
    createdAt: DateTime.utc(2026, 10, 19, 9),
    expiresAt: expires ?? DateTime.utc(2026, 10, 20, 9),
  );
}

void main() {
  group('SpaceBackup', () {
    test('is titled by its name, or its kind without one', () {
      expect(backup(name: 'Before the sale').title, 'Before the sale');
      expect(backup().title, 'Manual');
      expect(backup(kind: 'auto').title, 'Automatic');
      expect(backup(kind: 'pre-restore').title, 'Before a restore');
    });

    test('says who took it, and nothing for an automatic one', () {
      expect(
        backup(by: 'Alex').detail,
        'Manual by Alex - 12 games, 2 categories',
      );
      expect(backup(kind: 'auto').detail, 'Automatic - 12 games, 2 categories');
      expect(
        backup(name: 'Sale', by: 'Alex').detail,
        'Manual by Alex - 12 games, 2 categories',
      );
    });

    test('has a file name of its own', () {
      expect(backup().fileName, 'space-backup-4.json');
    });
  });

  group('RestoreRequest', () {
    test('tells the member who asked to wait for the partner', () {
      expect(
        request(mine: true).headline('Sam'),
        'Waiting for Sam to approve restoring "Before the sale".',
      );
    });

    test('asks the other member to approve', () {
      expect(
        request().headline('Alex'),
        'Alex wants to restore "Before the sale".',
      );
    });

    test('falls back to the date of an unnamed backup', () {
      final unnamed = RestoreRequest(
        id: 1,
        backupId: 4,
        backupName: null,
        backupCreatedAt: DateTime.utc(2026, 10, 19, 8, 30),
        requestedBy: 'Alex',
        requestedByMe: false,
        createdAt: DateTime.utc(2026, 10, 19, 9),
        expiresAt: DateTime.utc(2026, 10, 20, 9),
      );

      expect(
        unnamed.headline('Alex'),
        'Alex wants to restore the backup from 19 Oct 2026, 08:30.',
      );
    });

    test('says how long it can still be approved', () {
      final now = DateTime.utc(2026, 10, 19, 12);

      expect(request().timeLeft(now), '21 h left');
      expect(
        request(expires: DateTime.utc(2026, 10, 19, 12, 40)).timeLeft(now),
        '40 min left',
      );
      expect(
        request(expires: DateTime.utc(2026, 10, 19, 11)).timeLeft(now),
        'expired',
      );
    });
  });

  group('SpaceRestoreOutcome', () {
    test('is restored at once or waits for the partner', () {
      const done = SpaceRestoreOutcome.restored();
      final waiting = SpaceRestoreOutcome.waiting(request());

      expect(done.isRestored, isTrue);
      expect(waiting.isRestored, isFalse);
      expect(waiting.request!.id, 7);
    });
  });
}
