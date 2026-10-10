import 'package:backlog_manager/domain/status_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defaultStatuses', () {
    test('are the five built-in statuses in their order', () {
      expect(defaultStatuses, [
        'Not Started',
        'In Progress',
        'Completed',
        'On Hold',
        'Dropped',
      ]);
    });
  });

  group('statusNameError', () {
    test('has no message for an empty or blank name', () {
      expect(statusNameError('', const []), '');
      expect(statusNameError('   ', const []), '');
    });

    test('accepts a fresh name and a name of exactly 20 characters', () {
      expect(statusNameError('Replaying', const ['Wishlist']), '');
      expect(statusNameError('a' * 20, const []), '');
    });

    test('rejects more than 20 characters after trimming', () {
      expect(statusNameError('a' * 21, const []), 'Max 20 characters');
      expect(statusNameError('  ${'a' * 20}  ', const []), '');
    });

    test('rejects a default status, matching the case', () {
      expect(
        statusNameError('Completed', const []),
        "That's already a default status",
      );
      expect(statusNameError('completed', const []), '');
    });

    test('rejects an existing custom status of the same name', () {
      expect(
        statusNameError('Replaying', const ['Replaying']),
        'You already have a status with that name',
      );
      expect(
        statusNameError(' Replaying ', const ['Replaying']),
        'You already have a status with that name',
      );
    });

    test('names the length before the duplicates', () {
      expect(statusNameError('a' * 21, ['a' * 21]), 'Max 20 characters');
    });
  });
}
