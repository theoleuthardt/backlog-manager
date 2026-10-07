import 'package:backlog_manager/domain/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatHours', () {
    test('drops a zero fraction and keeps one decimal otherwise', () {
      expect(formatHours(41), '41');
      expect(formatHours(41.0), '41');
      expect(formatHours(8.5), '8.5');
      expect(formatHours(8.54), '8.5');
      expect(formatHours(0), '0');
    });
  });

  group('formatCount', () {
    test('separates thousands with a comma', () {
      expect(formatCount(0), '0');
      expect(formatCount(999), '999');
      expect(formatCount(1204), '1,204');
      expect(formatCount(1234567), '1,234,567');
    });
  });
}
