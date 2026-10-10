import 'package:backlog_manager/domain/two_factor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeTotpCode', () {
    test('drops the spaces of a code typed in groups', () {
      expect(normalizeTotpCode('123 456'), '123456');
      expect(normalizeTotpCode(' 12 34 56 '), '123456');
    });

    test('drops tabs and line breaks too', () {
      expect(normalizeTotpCode('123\t456\n'), '123456');
    });

    test('leaves a backup code alone apart from its spaces', () {
      expect(normalizeTotpCode('ab12-cd34'), 'ab12-cd34');
    });

    test('is empty for nothing but spaces', () {
      expect(normalizeTotpCode('   '), '');
    });
  });
}
