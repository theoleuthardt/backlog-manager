import 'package:backlog_manager/domain/wishlist_sync_report.dart';
import 'package:flutter_test/flutter_test.dart';

const portal = WishlistChange(steamAppId: 620, title: 'Portal 2');
const cs2 = WishlistChange(steamAppId: 730, title: 'Counter-Strike 2');
const cs = WishlistChange(steamAppId: 10, title: 'Counter-Strike');

void main() {
  final report = WishlistSyncReport(
    since: DateTime.utc(2026, 10, 9, 8),
    added: const [portal, cs2],
    removed: const [cs],
  );

  group('hasChanges', () {
    test('is true when a game was added or removed', () {
      expect(report.hasChanges, isTrue);
      expect(const WishlistSyncReport(removed: [cs]).hasChanges, isTrue);
    });

    test('is false for an empty report', () {
      expect(const WishlistSyncReport().hasChanges, isFalse);
    });
  });

  group('diffRows', () {
    test('lists the removed games as minus lines before the added ones', () {
      expect(report.diffRows.map((row) => '${row.sign} ${row.change.title}'), [
        '- Counter-Strike',
        '+ Portal 2',
        '+ Counter-Strike 2',
      ]);
    });
  });

  group('summary', () {
    test('counts both sides with singular and plural', () {
      expect(report.summary, '2 games added, 1 game removed since 9 Oct 2026');
    });

    test('leaves out the side without changes and the unknown date', () {
      expect(const WishlistSyncReport(added: [portal]).summary, '1 game added');
    });
  });
}
