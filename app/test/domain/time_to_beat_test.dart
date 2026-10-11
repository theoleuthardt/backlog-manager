import 'package:backlog_manager/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

BacklogEntry entry({double? main, double? extra, double? completion}) =>
    BacklogEntry(
      id: 1,
      title: 'Hades',
      mainTime: main,
      mainPlusExtraTime: extra,
      completionTime: completion,
    );

void main() {
  group('BacklogEntry.timeToBeat', () {
    test('is the main story when there is one', () {
      expect(entry(main: 20, extra: 30, completion: 50).timeToBeat, 20);
    });

    test('falls back to main plus extra when the main story is missing', () {
      expect(entry(extra: 30, completion: 50).timeToBeat, 30);
    });

    test('treats a main story of 0 hours as missing', () {
      expect(entry(main: 0, extra: 30).timeToBeat, 30);
    });

    test('falls back to the completionist time last', () {
      expect(entry(main: 0, extra: 0, completion: 50).timeToBeat, 50);
    });

    test('is null when no time is known', () {
      expect(entry().timeToBeat, isNull);
      expect(entry(main: 0, extra: 0, completion: 0).timeToBeat, isNull);
    });
  });
}
