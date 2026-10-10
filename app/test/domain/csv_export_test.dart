import 'package:backlog_manager/domain/csv_export.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

const hades = BacklogEntry(
  id: 1,
  title: 'Hades',
  genre: ['Roguelike', 'Action'],
  platform: ['PC', 'Switch'],
  status: 'Completed',
  owned: true,
  interest: 9,
  reviewStars: 10,
  review: 'Great',
  note: 'Replay',
  mainTime: 22,
  mainPlusExtraTime: 48.5,
  completionTime: 95,
  imageLink: 'https://img.example/h.jpg',
);

/// A small reader of the CSV the export writes (quotes doubled, commas and
/// line breaks allowed inside quotes), to read an export back the way a
/// spreadsheet or the importer does.
List<List<String>> readCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  row.add(field.toString());
  rows.add(row);
  return rows;
}

void main() {
  group('buildCsv', () {
    test('writes the columns of the web export without a header row', () {
      expect(
        buildCsv([hades]),
        '"Hades","Roguelike, Action","PC, Switch","Completed",true,9,10,'
        '"Great","Replay",22,48.5,95,"https://img.example/h.jpg"',
      );
    });

    test('puts one entry on each line with no line break at the end', () {
      final csv = buildCsv([hades, hades]);

      expect(csv.split('\n'), hasLength(2));
      expect(csv.endsWith('\n'), isFalse);
    });

    test('is empty for no entries', () {
      expect(buildCsv(const []), '');
    });

    test('doubles the quotes of every text field', () {
      final csv = buildCsv([
        const BacklogEntry(
          id: 2,
          title: 'The "Best" Game',
          genre: ['Say "hi"'],
          platform: ['PC'],
          review: 'He said "wow"',
          note: '"',
          imageLink: 'u"v',
        ),
      ]);

      expect(
        csv,
        '"The ""Best"" Game","Say ""hi""","PC","Not Started",false,0,,'
        '"He said ""wow""","""",,,,"u""v"',
      );
    });

    test('leaves the numbers that are missing empty', () {
      final csv = buildCsv([const BacklogEntry(id: 3, title: 'Bare')]);

      expect(csv, '"Bare","","","Not Started",false,0,,"","",,,,""');
    });

    test('writes whole hours without a decimal like the web client', () {
      final csv = buildCsv([
        const BacklogEntry(
          id: 4,
          title: 'T',
          mainTime: 10,
          mainPlusExtraTime: 12.25,
          completionTime: 0.5,
        ),
      ]);

      expect(readCsv(csv).single.sublist(9, 12), ['10', '12.25', '0.5']);
    });

    test('empties the review and the note, but not their columns', () {
      final csv = buildCsv([hades], includeReviews: false);

      expect(
        csv,
        '"Hades","Roguelike, Action","PC, Switch","Completed",true,9,10,'
        '"","",22,48.5,95,"https://img.example/h.jpg"',
      );
      expect(readCsv(csv).single, hasLength(13));
    });
  });

  group('an export read back', () {
    test('has the columns A to M in the order of the import', () {
      final row = readCsv(buildCsv([hades])).single;

      expect(row, hasLength(13));
      expect(row[0], 'Hades');
      expect(row[1], 'Roguelike, Action');
      expect(row[2], 'PC, Switch');
      expect(row[3], 'Completed');
      expect(row[4], 'true');
      expect(row[5], '9');
      expect(row[6], '10');
      expect(row[7], 'Great');
      expect(row[8], 'Replay');
      expect(row[9], '22');
      expect(row[10], '48.5');
      expect(row[11], '95');
      expect(row[12], 'https://img.example/h.jpg');
    });

    test('keeps commas, quotes and line breaks of a note', () {
      final row = readCsv(
        buildCsv([
          const BacklogEntry(
            id: 5,
            title: 'A, B',
            note: 'line 1\nline "2", done',
          ),
        ]),
      ).single;

      expect(row[0], 'A, B');
      expect(row[8], 'line 1\nline "2", done');
      expect(row, hasLength(13));
    });

    test('has as many rows as there were entries', () {
      final rows = readCsv(buildCsv([hades, hades, hades]));

      expect(rows, hasLength(3));
    });
  });

  group('entriesWithStatus', () {
    final entries = [
      const BacklogEntry(id: 1, title: 'A', status: 'Completed'),
      const BacklogEntry(id: 2, title: 'B', status: 'Dropped'),
      const BacklogEntry(id: 3, title: 'C', status: 'Completed'),
    ];

    test('keeps everything without a status', () {
      expect(entriesWithStatus(entries, null), entries);
    });

    test('keeps the entries of one status', () {
      expect(entriesWithStatus(entries, 'Completed').map((e) => e.id), [1, 3]);
      expect(entriesWithStatus(entries, 'On Hold'), isEmpty);
    });
  });

  group('exportFileName', () {
    test('is named after the day, in UTC like the web client', () {
      expect(
        exportFileName(DateTime.utc(2026, 10, 9, 23, 59)),
        'backlog-export-2026-10-09.csv',
      );
      expect(
        exportFileName(DateTime.utc(2026, 1, 2)),
        'backlog-export-2026-01-02.csv',
      );
    });
  });
}
