import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/status_names.dart';
import 'package:flutter_test/flutter_test.dart';

BacklogEntry entry({required String status, required bool owned}) =>
    BacklogEntry(
      id: 1,
      title: 'Hades',
      status: status,
      owned: owned,
      interest: 5,
    );

void main() {
  group('withStatus keeps the ownership in step like the server', () {
    test('moving to Not Owned marks the game as not owned', () {
      final moved = entry(
        status: 'In Progress',
        owned: true,
      ).withStatus(notOwnedStatus);

      expect(moved.status, 'Not Owned');
      expect(moved.owned, isFalse);
    });

    test('moving out of Not Owned marks the game as owned', () {
      final moved = entry(
        status: notOwnedStatus,
        owned: false,
      ).withStatus('In Progress');

      expect(moved.status, 'In Progress');
      expect(moved.owned, isTrue);
    });

    test('in a shared space the ownership stays with the member', () {
      expect(
        entry(
          status: 'In Progress',
          owned: true,
        ).withStatus(notOwnedStatus, ownershipFollows: false).owned,
        isTrue,
      );
      expect(
        entry(
          status: notOwnedStatus,
          owned: false,
        ).withStatus('In Progress', ownershipFollows: false).owned,
        isFalse,
      );
    });

    test('moving between ordinary statuses leaves the ownership alone', () {
      expect(
        entry(status: 'In Progress', owned: true).withStatus('Dropped').owned,
        isTrue,
      );
      expect(
        entry(status: 'Dropped', owned: false).withStatus('Completed').owned,
        isFalse,
      );
    });
  });
}
