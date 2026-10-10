import 'package:backlog_manager/domain/backups.dart';
import 'package:backlog_manager/domain/safe_url.dart';
import 'package:backlog_manager/domain/split_list.dart';
import 'package:backlog_manager/domain/status_style.dart';
import 'package:backlog_manager/domain/trailer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isHttpUrl', () {
    test('accepts http and https urls', () {
      expect(isHttpUrl('https://www.cheapshark.com/redirect?dealID=abc'), true);
      expect(isHttpUrl('http://example.com/game'), true);
    });

    test('rejects script and data urls that would run when clicked', () {
      expect(isHttpUrl('javascript:alert(1)'), false);
      expect(isHttpUrl('data:text/html,<script>alert(1)</script>'), false);
      expect(isHttpUrl('vbscript:msgbox(1)'), false);
    });

    test('rejects a url without a host', () {
      expect(isHttpUrl('https://'), false);
      expect(isHttpUrl('http://'), false);
    });

    test('accepts a scheme without the slashes like the WHATWG parser', () {
      expect(isHttpUrl('https:example.com'), true);
      expect(isHttpUrl('http:/example.com/game'), true);
      expect(isHttpUrl('HTTPS://Example.com'), true);
    });

    test('rejects a scheme followed only by slashes', () {
      expect(isHttpUrl('https:///'), false);
      expect(isHttpUrl('https:'), false);
    });

    test('rejects relative, protocol-relative and malformed values', () {
      expect(isHttpUrl('/redirect?dealID=abc'), false);
      expect(isHttpUrl('//example.com'), false);
      expect(isHttpUrl('not a url'), false);
      expect(isHttpUrl(''), false);
    });
  });

  group('youtubeEmbedUrl', () {
    test('turns a YouTube watch link into a privacy-friendly embed url', () {
      expect(
        youtubeEmbedUrl('https://www.youtube.com/watch?v=abc123DEF45'),
        'https://www.youtube-nocookie.com/embed/abc123DEF45',
      );
    });

    test('accepts ids containing dashes and underscores', () {
      expect(
        youtubeEmbedUrl('https://www.youtube.com/watch?v=a-b_c1D2e3F'),
        'https://www.youtube-nocookie.com/embed/a-b_c1D2e3F',
      );
    });

    test('returns null when there is no link', () {
      expect(youtubeEmbedUrl(null), isNull);
      expect(youtubeEmbedUrl(''), isNull);
    });

    test('returns null for anything that is not a canonical watch link', () {
      expect(youtubeEmbedUrl('javascript:alert(1)'), isNull);
      expect(
        youtubeEmbedUrl('https://example.com/watch?v=abc123DEF45'),
        isNull,
      );
      expect(
        youtubeEmbedUrl(
          'https://www.youtube.com.evil.example/watch?v=abc123DEF45',
        ),
        isNull,
      );
      expect(
        youtubeEmbedUrl('https://www.youtube.com/watch?v=tooshort'),
        isNull,
      );
      expect(
        youtubeEmbedUrl(
          'https://www.youtube.com/watch?v=abc123DEF45&autoplay=1',
        ),
        isNull,
      );
    });
  });

  group('splitList', () {
    test('splits on commas and trims every item', () {
      expect(splitList('RPG, Indie ,Platformer'), [
        'RPG',
        'Indie',
        'Platformer',
      ]);
    });

    test('drops empty items', () {
      expect(splitList('RPG,, ,Indie,'), ['RPG', 'Indie']);
    });

    test('returns an empty list for an empty or blank string', () {
      expect(splitList(''), isEmpty);
      expect(splitList('   '), isEmpty);
    });

    test('keeps a single item as is', () {
      expect(splitList('PC'), ['PC']);
    });
  });

  group('statusColor', () {
    test('has a colour for every default status', () {
      expect(statusColor('Not Started'), '#94a3b8');
      expect(statusColor('In Progress'), '#38bdf8');
      expect(statusColor('Completed'), '#4ade80');
      expect(statusColor('On Hold'), '#fbbf24');
      expect(statusColor('Dropped'), '#f87171');
    });

    test('gives custom statuses one shared colour', () {
      expect(statusColor('Replaying'), '#c084fc');
    });
  });

  group('backupKindLabel', () {
    test('names every backup kind the backend creates', () {
      expect(backupKindLabel('auto'), 'Automatic');
      expect(backupKindLabel('manual'), 'Manual');
      expect(backupKindLabel('pre-restore'), 'Before a restore');
      expect(backupKindLabel('pre-delete'), 'Before deleting all games');
      expect(backupKindLabel('pre-import'), 'Before a CSV import');
    });

    test('falls back to the raw kind for one it does not know', () {
      expect(backupKindLabel('something-new'), 'something-new');
    });
  });

  group('backupContentSummary', () {
    test('counts games and categories', () {
      expect(
        backupContentSummary(entryCount: 12, categoryCount: 3),
        '12 games, 3 categories',
      );
    });

    test('uses the singular for exactly one', () {
      expect(
        backupContentSummary(entryCount: 1, categoryCount: 1),
        '1 game, 1 category',
      );
    });

    test('handles an empty backlog', () {
      expect(
        backupContentSummary(entryCount: 0, categoryCount: 0),
        '0 games, 0 categories',
      );
    });
  });

  group('backupTitle', () {
    test('prefers the name the user gave', () {
      expect(
        backupTitle(name: 'Before the sale', kind: 'manual'),
        'Before the sale',
      );
    });

    test('falls back to the kind label without a name', () {
      expect(backupTitle(name: null, kind: 'auto'), 'Automatic');
    });
  });

  group('normalizeBackupName', () {
    test('trims surrounding whitespace', () {
      expect(normalizeBackupName('  Pre-sale  '), 'Pre-sale');
    });

    test('turns a blank name into null so the label is cleared', () {
      expect(normalizeBackupName(''), isNull);
      expect(normalizeBackupName('   '), isNull);
    });

    test("matches the backend's length limit", () {
      expect(maxBackupNameLength, 60);
    });
  });

  group('the backup dates', () {
    test('read the zone-less time of the server as UTC', () {
      final read = serverTimeAsUtc(DateTime(2026, 10, 9, 8, 7, 6));

      expect(read.isUtc, isTrue);
      expect((read.year, read.month, read.day), (2026, 10, 9));
      expect((read.hour, read.minute, read.second), (8, 7, 6));
    });

    test('are written as day, month, year and the time', () {
      expect(
        backupDateLabel(DateTime.utc(2026, 10, 9, 8, 7), toLocal: false),
        '9 Oct 2026, 08:07',
      );
      expect(
        backupDateLabel(DateTime.utc(2026, 1, 31, 23, 59), toLocal: false),
        '31 Jan 2026, 23:59',
      );
    });
  });

  group('Backup', () {
    final backup = Backup(
      id: 4,
      kind: 'manual',
      name: null,
      createdAt: DateTime.utc(2026, 10, 9, 8, 7),
      entryCount: 148,
      categoryCount: 1,
    );

    test('is titled by its name or its kind', () {
      expect(backup.title, 'Manual');
      expect(
        Backup(
          id: 5,
          kind: 'auto',
          name: 'Before the move',
          createdAt: backup.createdAt,
          entryCount: 1,
          categoryCount: 0,
        ).title,
        'Before the move',
      );
    });

    test('summarises its content', () {
      expect(backup.summary, '148 games, 1 category');
    });

    test('names its kind next to the summary only when it has a name', () {
      expect(backup.detail, '148 games, 1 category');
      expect(
        Backup(
          id: 5,
          kind: 'auto',
          name: 'Mine',
          createdAt: backup.createdAt,
          entryCount: 2,
          categoryCount: 0,
        ).detail,
        'Automatic - 2 games, 0 categories',
      );
    });

    test('is saved as a file named after its id', () {
      expect(backup.fileName, 'backlog-backup-4.json');
    });
  });

  group('RestoreResult', () {
    test('says what came back and whether the old state was kept', () {
      const kept = RestoreResult(
        entryCount: 148,
        categoryCount: 3,
        safetyBackupId: 9,
      );
      const none = RestoreResult(entryCount: 1, categoryCount: 0);

      expect(
        kept.message,
        'Restored 148 games, 3 categories. Your previous state was saved as a '
        'backup.',
      );
      expect(none.message, 'Restored 1 game, 0 categories.');
    });
  });
}
