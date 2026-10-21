import 'package:backlog_manager/domain/sanitize.dart';
import 'package:flutter_test/flutter_test.dart';

final rlo = String.fromCharCode(0x202E);
final pdf = String.fromCharCode(0x202C);
final zwsp = String.fromCharCode(0x200B);
final zwj = String.fromCharCode(0x200D);
final wj = String.fromCharCode(0x2060);
final bom = String.fromCharCode(0xFEFF);
final lrm = String.fromCharCode(0x200E);
final rlm = String.fromCharCode(0x200F);
final lri = String.fromCharCode(0x2066);
final pdi = String.fromCharCode(0x2069);

void main() {
  group('sanitizeText', () {
    test('removes bidi overrides and zero-width characters', () {
      expect(
        sanitizeText('${rlo}evil$pdf$zwsp$wj$bom$lrm$rlm${lri}x$pdi'),
        'evilx',
      );
    });

    test('trims whitespace at the edges', () {
      expect(sanitizeText('  Celeste \n'), 'Celeste');
    });

    test('keeps punctuation that looks like code', () {
      const title = 'Assassin\'s Creed; {Deluxe} "<GOTY>" -- 100% /* */';
      expect(sanitizeText(title), title);
    });

    test('keeps line breaks and tabs inside the text', () {
      expect(
        sanitizeText('line one\n\tline two\r\nthree'),
        'line one\n\tline two\r\nthree',
      );
    });

    test('removes other control characters', () {
      final controls = [0x00, 0x07, 0x1B, 0x7F, 0x85, 0x9F];
      final input = StringBuffer('a');
      for (var i = 0; i < controls.length; i++) {
        input
          ..writeCharCode(controls[i])
          ..write('bcdefg'[i]);
      }
      expect(sanitizeText(input.toString()), 'abcdefg');
    });

    test('keeps emoji joined with the zero-width joiner', () {
      final family = [
        String.fromCharCode(0x1F468),
        String.fromCharCode(0x1F469),
        String.fromCharCode(0x1F467),
      ].join(zwj);
      expect(sanitizeText(family), family);
    });
  });

  group('sanitizeJson', () {
    test('sanitizes every string value but not passwords or keys', () {
      final tree = <String, Object?>{
        'title': ' Celeste$zwsp ',
        'password': '  ${zwsp}exactly as typed ',
        'genre': [' Platformer ', '${rlo}Indie'],
        'nested': {'name': '${lri}x$pdi', 'password': ' inner '},
        'interest': 8,
        'owned': true,
        'note': null,
        ' key ': 'value',
      };

      expect(sanitizeJson(tree), {
        'title': 'Celeste',
        'password': '  ${zwsp}exactly as typed ',
        'genre': ['Platformer', 'Indie'],
        'nested': {'name': 'x', 'password': ' inner '},
        'interest': 8,
        'owned': true,
        'note': null,
        ' key ': 'value',
      });
    });

    test('sanitizes a bare string or list body', () {
      expect(sanitizeJson(' a$zwsp '), 'a');
      expect(sanitizeJson([' a ', 1]), ['a', 1]);
    });
  });

  group('the username and e-mail rules', () {
    test('accepts usernames the server lets be set', () {
      expect(isValidUsername('alex'), isTrue);
      expect(isValidUsername('Player-1.x_y'), isTrue);
      expect(isValidUsername('a' * 32), isTrue);
    });

    test('refuses usernames the server does not let be set', () {
      for (final name in [
        '',
        'ab',
        'a' * 33,
        'two words',
        "admin'--",
        '<script>',
        'semi;colon',
        'line\nbreak',
      ]) {
        expect(isValidUsername(name), isFalse, reason: name);
      }
    });

    test('checks the shape of an e-mail address loosely', () {
      expect(looksLikeEmail('theo@example.com'), isTrue);
      expect(looksLikeEmail('admin@localhost'), isTrue);
      for (final email in [
        '',
        'theo',
        'theo@',
        '@example.com',
        'two@@example.com',
        'spaces in@example.com',
      ]) {
        expect(looksLikeEmail(email), isFalse, reason: email);
      }
    });
  });
}
