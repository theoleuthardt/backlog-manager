import 'package:backlog_manager/domain/bulk_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bulkStatusMessage', () {
    test('counts the moved games', () {
      expect(
        bulkStatusMessage(succeeded: 3, failed: 0, status: 'Completed'),
        'Moved 3 games to Completed',
      );
    });

    test('uses the singular for one game', () {
      expect(
        bulkStatusMessage(succeeded: 1, failed: 0, status: 'Dropped'),
        'Moved 1 game to Dropped',
      );
    });

    test('reports the failures', () {
      expect(
        bulkStatusMessage(succeeded: 2, failed: 1, status: 'On Hold'),
        'Moved 2 to On Hold, 1 failed',
      );
    });
  });

  group('bulkDeleteMessage', () {
    test('names a single game', () {
      expect(
        bulkDeleteMessage(succeeded: 1, failed: 0, singleTitle: 'Hades'),
        '"Hades" deleted',
      );
    });

    test('counts several games', () {
      expect(bulkDeleteMessage(succeeded: 4, failed: 0), 'Deleted 4 games');
    });

    test('reports the failures', () {
      expect(
        bulkDeleteMessage(succeeded: 2, failed: 3, singleTitle: null),
        'Deleted 2, 3 failed',
      );
    });
  });

  group('deleteTitle and deleteDescription', () {
    test('ask about one game by its title', () {
      expect(deleteTitle(['Hades']), 'Delete "Hades"?');
      expect(
        deleteDescription(1),
        'This action cannot be undone. This will permanently delete this '
        'backlog entry from your collection.',
      );
    });

    test('ask about several games by their number', () {
      expect(deleteTitle(['A', 'B', 'C']), 'Delete 3 games?');
      expect(
        deleteDescription(3),
        'This action cannot be undone. This will permanently delete these '
        'backlog entries from your collection.',
      );
    });
  });

  group('bulkCategoryMessage', () {
    test('says how many games got the category', () {
      expect(
        bulkCategoryMessage(
          added: true,
          category: 'Story',
          succeeded: 3,
          failed: 0,
        ),
        'Added 3 games to "Story"',
      );
    });

    test('says how many games lost it', () {
      expect(
        bulkCategoryMessage(
          added: false,
          category: 'Story',
          succeeded: 1,
          failed: 0,
        ),
        'Removed 1 game from "Story"',
      );
    });

    test('reports the failures', () {
      expect(
        bulkCategoryMessage(
          added: true,
          category: 'Story',
          succeeded: 2,
          failed: 1,
        ),
        'Added 2 to "Story", 1 failed',
      );
    });
  });
}
