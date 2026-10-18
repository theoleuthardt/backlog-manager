import 'package:backlog_manager/domain/entry_mod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateMod', () {
    test('needs a name', () {
      expect(validateMod('', ''), 'Enter the name of the mod');
      expect(validateMod('   ', 'https://a.example'), isNotNull);
    });

    test('keeps the name to 120 characters', () {
      expect(validateMod('x' * 120, ''), isNull);
      expect(
        validateMod('x' * 121, ''),
        'The name can have up to 120 characters',
      );
    });

    test('takes no link or an http(s) link', () {
      expect(validateMod('Mod', ''), isNull);
      expect(validateMod('Mod', '  '), isNull);
      expect(validateMod('Mod', 'https://www.nexusmods.com/mod/1'), isNull);
      expect(validateMod('Mod', 'http://example.com/m'), isNull);
    });

    test('rejects every other kind of link', () {
      const message = 'The link must start with http:// or https://';
      expect(validateMod('Mod', 'javascript:alert(1)'), message);
      expect(validateMod('Mod', 'ftp://example.com'), message);
      expect(validateMod('Mod', 'nexusmods.com/mod/1'), message);
    });
  });

  test('modLink is the trimmed link or null for a blank one', () {
    expect(modLink(' https://a.example/m '), 'https://a.example/m');
    expect(modLink('   '), isNull);
  });
}
