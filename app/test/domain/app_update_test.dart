import 'package:backlog_manager/domain/app_update.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> release({
  String tag = 'v0.9.4',
  bool draft = false,
  bool prerelease = false,
  String? body = 'Notes',
  String url =
      'https://github.com/theoleuthardt/backlog-manager/releases/tag/v0.9.4',
}) => {
  'tag_name': tag,
  'draft': draft,
  'prerelease': prerelease,
  'body': body,
  'html_url': url,
};

void main() {
  group('parseVersion', () {
    test('reads plain and v-prefixed versions', () {
      expect(parseVersion('1.2.3'), [1, 2, 3]);
      expect(parseVersion('v0.9.10'), [0, 9, 10]);
    });

    test('rejects anything that is not X.Y.Z', () {
      expect(parseVersion('1.2'), isNull);
      expect(parseVersion('v1.2.3-beta'), isNull);
      expect(parseVersion('1.2.3+4'), isNull);
      expect(parseVersion(''), isNull);
    });
  });

  group('isNewerVersion', () {
    test('compares numerically, not as text', () {
      expect(isNewerVersion('0.9.10', than: '0.9.9'), isTrue);
      expect(isNewerVersion('1.0.0', than: '0.99.99'), isTrue);
    });

    test('is false for the same or an older version', () {
      expect(isNewerVersion('0.9.3', than: '0.9.3'), isFalse);
      expect(isNewerVersion('0.9.2', than: '0.9.3'), isFalse);
    });

    test('is false when either version is unreadable', () {
      expect(isNewerVersion('nightly', than: '0.9.3'), isFalse);
      expect(isNewerVersion('0.9.4', than: 'dev'), isFalse);
    });
  });

  group('appReleaseFromJson', () {
    test('reads version, notes and page of a release', () {
      final result = appReleaseFromJson(release())!;

      expect(result.version, '0.9.4');
      expect(result.notes, 'Notes');
      expect(result.pageUrl.toString(), contains('/releases/tag/v0.9.4'));
    });

    test('ignores drafts and pre-releases', () {
      expect(appReleaseFromJson(release(draft: true)), isNull);
      expect(appReleaseFromJson(release(prerelease: true)), isNull);
    });

    test('takes a pre-release when asked to, never a draft', () {
      expect(
        appReleaseFromJson(
          release(prerelease: true),
          allowPrerelease: true,
        )?.version,
        '0.9.4',
      );
      expect(
        appReleaseFromJson(release(draft: true), allowPrerelease: true),
        isNull,
      );
    });

    test('ignores a tag that is not a plain version', () {
      expect(appReleaseFromJson(release(tag: 'nightly')), isNull);
    });

    test('keeps the notes empty when the release has none', () {
      expect(appReleaseFromJson(release(body: null))!.notes, isEmpty);
      expect(appReleaseFromJson(release(body: '  \n'))!.notes, isEmpty);
    });

    test('only accepts release pages of GitHub', () {
      expect(
        appReleaseFromJson(release(url: 'https://evil.example/x')),
        isNull,
      );
      expect(appReleaseFromJson(release(url: 'javascript:alert(1)')), isNull);
    });
  });
}
