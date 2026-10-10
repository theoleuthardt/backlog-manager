import 'package:backlog_manager/domain/igdb_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pendingLabel', () {
    test('counts while the number is not known', () {
      expect(pendingLabel(null, failed: false), 'Counting games...');
    });

    test('says so when the count failed', () {
      expect(
        pendingLabel(null, failed: true),
        'Could not count the games to sync.',
      );
    });

    test('says that nothing is left to do', () {
      expect(
        pendingLabel(0, failed: false),
        'Every game already has IGDB data.',
      );
    });

    test('uses the singular for one game', () {
      expect(pendingLabel(1, failed: false), '1 game will be looked up.');
    });

    test('names the number of games', () {
      expect(pendingLabel(12, failed: false), '12 games will be looked up.');
    });
  });

  group('syncResultMessage', () {
    test('says that nothing could be added', () {
      expect(syncResultMessage(0), 'No IGDB data could be added');
    });

    test('uses the singular for one game', () {
      expect(syncResultMessage(1), 'Updated 1 game with IGDB data');
    });

    test('names the number of updated games', () {
      expect(syncResultMessage(5), 'Updated 5 games with IGDB data');
    });
  });

  group('progressLabel', () {
    test('starts before the first progress arrives', () {
      expect(progressLabel(null, null), 'Starting...');
    });

    test('shows processed and total', () {
      expect(progressLabel(3, 10), 'Looking up games 3/10');
    });
  });

  group('syncFraction', () {
    test('is zero without progress or without games', () {
      expect(syncFraction(null, null), 0);
      expect(syncFraction(0, 0), 0);
    });

    test('is the share that is done', () {
      expect(syncFraction(1, 4), 0.25);
      expect(syncFraction(4, 4), 1);
    });
  });
}
