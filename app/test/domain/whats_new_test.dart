import 'package:backlog_manager/domain/whats_new.dart';
import 'package:flutter_test/flutter_test.dart';

const _notes = '''
## Installing

The installers are not code signed, so macOS and Windows warn on the first start:

- **macOS:** right click the app > Open.
- **Android** (8.0 or newer): open the APK on the device.

## What's Changed
* fix(app): controller on the handheld: no grey veil, search keyboard only after A by @theo-claude in https://github.com/theoleuthardt/backlog-manager/pull/573
* feat(app): handheld landscape after DroidDeck: gliding focus selector by @theo-claude in https://github.com/theoleuthardt/backlog-manager/pull/569
* docs: explain the backups by @theoleuthardt in https://github.com/theoleuthardt/backlog-manager/pull/500
* Fix the sign-in on iOS by @someone in https://github.com/theoleuthardt/backlog-manager/pull/1


**Full Changelog**: https://github.com/theoleuthardt/backlog-manager/compare/v0.9.16...v0.9.17
''';

void main() {
  group('releaseChanges', () {
    test('lists the pull requests of "What\'s Changed" in plain words', () {
      expect(releaseChanges(_notes), [
        'Controller on the handheld: no grey veil, search keyboard only '
            'after A',
        'Handheld landscape after DroidDeck: gliding focus selector',
        'Explain the backups',
        'Fix the sign-in on iOS',
      ]);
    });

    test('leaves out the installation notes and the changelog link', () {
      final changes = releaseChanges(_notes);

      expect(changes.any((line) => line.contains('macOS')), isFalse);
      expect(changes.any((line) => line.contains('Changelog')), isFalse);
    });

    test('is empty without a "What\'s Changed" section', () {
      expect(releaseChanges(''), isEmpty);
      expect(releaseChanges('## Installing\n\n- **macOS:** open it'), isEmpty);
    });

    test('takes dashes as bullets and stops at the next heading', () {
      const notes =
          "## What's Changed\n"
          '- feat: a new thing\n'
          '- fix(app)!: a breaking fix\n'
          '\n'
          '## New Contributors\n'
          '* @someone made their first contribution\n';

      expect(releaseChanges(notes), ['A new thing', 'A breaking fix']);
    });
  });

  group('shouldShowWhatsNew', () {
    test('shows after an update to a newer version', () {
      expect(
        shouldShowWhatsNew(installed: '0.9.18', lastSeen: '0.9.17'),
        isTrue,
      );
      expect(
        shouldShowWhatsNew(installed: '1.0.0', lastSeen: '0.9.17'),
        isTrue,
      );
    });

    test('never on a first install', () {
      expect(shouldShowWhatsNew(installed: '0.9.18', lastSeen: null), isFalse);
    });

    test('for an install from before this feature that was in use', () {
      expect(
        shouldShowWhatsNew(
          installed: '0.9.18',
          lastSeen: null,
          inUseBefore: true,
        ),
        isTrue,
      );
    });

    test('not again for the same version, nor after a downgrade', () {
      expect(
        shouldShowWhatsNew(installed: '0.9.18', lastSeen: '0.9.18'),
        isFalse,
      );
      expect(
        shouldShowWhatsNew(installed: '0.9.17', lastSeen: '0.9.18'),
        isFalse,
      );
    });
  });
}
