import 'package:backlog_manager/domain/keyforsteam.dart';
import 'package:backlog_manager/domain/safe_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('keyforsteamSearchUrl', () {
    test('is the catalog search of Keyforsteam with the title as the term', () {
      expect(
        keyforsteamSearchUrl('Hades II'),
        'https://www.keyforsteam.de/katalog/search-Hades%20II',
      );
    });

    test('escapes characters that would end the path segment', () {
      expect(
        keyforsteamSearchUrl('Half-Life 2: Episode/Two?'),
        'https://www.keyforsteam.de/katalog/search-'
        'Half-Life%202%3A%20Episode%2FTwo%3F',
      );
    });

    test('is a link that is safe to open', () {
      expect(isHttpUrl(keyforsteamSearchUrl("Baldur's Gate 3")), isTrue);
    });
  });

  group('staysOnKeyforsteam', () {
    test('lets the pages of Keyforsteam load', () {
      expect(
        staysOnKeyforsteam(Uri.parse('https://www.keyforsteam.de/hades-key')),
        isTrue,
      );
      expect(
        staysOnKeyforsteam(
          Uri.parse('https://keyforsteam.de/katalog/search-x'),
        ),
        isTrue,
      );
      expect(
        staysOnKeyforsteam(Uri.parse('https://cdn.keyforsteam.de/a/b')),
        isTrue,
      );
    });

    test('sends everything else, such as the shops, to the browser', () {
      for (final url in [
        'https://www.kinguin.net/category/1',
        'https://keyforsteam.de.evil.example/',
        'https://evilkeyforsteam.de/',
        'http://www.keyforsteam.de/insecure',
        'file:///etc/passwd',
        'javascript:alert(1)',
        'mailto:a@keyforsteam.de',
      ]) {
        expect(staysOnKeyforsteam(Uri.parse(url)), isFalse, reason: url);
      }
    });
  });
}
