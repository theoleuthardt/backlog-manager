import 'package:backlog_manager/domain/update_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> manifest({
  String version = '1.2.3',
  Map<String, dynamic>? payloads,
  String pageUrl = 'https://github.com/o/r/releases/tag/v1.2.3',
}) => {
  'version': version,
  'pub_date': '2026-10-12T00:00:00.000Z',
  'notes': 'Fixes',
  'page_url': pageUrl,
  'payloads':
      payloads ??
      {
        'linux-x64-appimage': {
          'url': 'https://github.com/o/r/releases/download/v1.2.3/Backlog-Manager_1.2.3_linux_x64.AppImage',
          'sha256': 'a' * 64,
          'size': 1024,
          'signature': 'c2lnbmF0dXJl',
        },
      },
};

void main() {
  group('parseUpdateManifest', () {
    test('reads the version, the notes, the page and the payloads', () {
      final parsed = parseUpdateManifest(manifest())!;

      expect(parsed.version, '1.2.3');
      expect(parsed.notes, 'Fixes');
      expect(parsed.pageUrl.host, 'github.com');
      final payload = parsed.payloads['linux-x64-appimage']!;
      expect(payload.sha256, 'a' * 64);
      expect(payload.size, 1024);
      expect(payload.url.path, endsWith('.AppImage'));
    });

    test('is null for something that is not an object', () {
      expect(parseUpdateManifest('x'), isNull);
      expect(parseUpdateManifest(null), isNull);
      expect(parseUpdateManifest(<String, dynamic>{}), isNull);
    });

    test('is null for a version that is not a plain X.Y.Z', () {
      expect(parseUpdateManifest(manifest(version: '1.2.3-beta')), isNull);
    });

    test('drops a payload whose address is not an https github.com one', () {
      final parsed = parseUpdateManifest(
        manifest(
          payloads: {
            'linux-x64-appimage': {
              'url': 'http://github.com/o/r/a.AppImage',
              'sha256': 'a' * 64,
              'size': 1,
              'signature': 'c2ln',
            },
            'macos-universal-dmg': {
              'url': 'https://evil.example.com/a.dmg',
              'sha256': 'a' * 64,
              'size': 1,
              'signature': 'c2ln',
            },
          },
        ),
      )!;

      expect(parsed.payloads, isEmpty);
    });

    test('drops a payload with a malformed hash or without a signature', () {
      final parsed = parseUpdateManifest(
        manifest(
          payloads: {
            'linux-x64-appimage': {
              'url': 'https://github.com/o/r/a.AppImage',
              'sha256': 'not-a-hash',
              'size': 1,
              'signature': 'c2ln',
            },
            'windows-x64-exe': {
              'url': 'https://github.com/o/r/a.exe',
              'sha256': 'b' * 64,
              'size': 1,
            },
          },
        ),
      )!;

      expect(parsed.payloads, isEmpty);
    });

    test('has no page when the address is not on github.com', () {
      final parsed = parseUpdateManifest(
        manifest(pageUrl: 'https://evil.example.com/x'),
      );

      expect(parsed, isNull);
    });
  });

  group('updateMessage', () {
    test('binds the signature to the version, the platform and the hash', () {
      expect(
        updateMessage(
          version: '1.2.3',
          key: 'linux-x64-appimage',
          sha256: 'ab',
        ),
        'blm-update-v1:1.2.3:linux-x64-appimage:ab',
      );
    });
  });
}
