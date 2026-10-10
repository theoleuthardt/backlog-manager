import 'dart:convert';

import 'package:backlog_manager/domain/backups.dart';
import 'package:backlog_manager/domain/diff_fields.dart';
import 'package:backlog_manager/domain/game_search.dart';

/// Which column of the CSV file holds which field. Columns are the letters of
/// a spreadsheet (A, B, ... Z, AA); the first four are required.
class CsvColumnConfig {
  const CsvColumnConfig({
    this.titleColumn = 'A',
    this.genreColumn = 'B',
    this.platformColumn = 'C',
    this.statusColumn = 'D',
    this.playtimeColumn,
    this.ratingColumn,
    this.completedAtColumn,
    this.noteColumns = const [],
    this.reviewColumns = const [],
  });

  final String titleColumn;
  final String genreColumn;
  final String platformColumn;
  final String statusColumn;
  final String? playtimeColumn;
  final String? ratingColumn;
  final String? completedAtColumn;

  /// Merged into the note as "Header: Value".
  final List<String> noteColumns;

  /// Merged into the review text.
  final List<String> reviewColumns;

  CsvColumnConfig copyWith({
    String? titleColumn,
    String? genreColumn,
    String? platformColumn,
    String? statusColumn,
    String? playtimeColumn,
    bool clearPlaytime = false,
    String? ratingColumn,
    bool clearRating = false,
    String? completedAtColumn,
    bool clearCompletedAt = false,
  }) {
    return CsvColumnConfig(
      titleColumn: titleColumn ?? this.titleColumn,
      genreColumn: genreColumn ?? this.genreColumn,
      platformColumn: platformColumn ?? this.platformColumn,
      statusColumn: statusColumn ?? this.statusColumn,
      playtimeColumn: clearPlaytime
          ? null
          : playtimeColumn ?? this.playtimeColumn,
      ratingColumn: clearRating ? null : ratingColumn ?? this.ratingColumn,
      completedAtColumn: clearCompletedAt
          ? null
          : completedAtColumn ?? this.completedAtColumn,
      noteColumns: noteColumns,
      reviewColumns: reviewColumns,
    );
  }

  CsvColumnConfig withReviewColumn(String letter, {required bool on}) {
    return CsvColumnConfig(
      titleColumn: titleColumn,
      genreColumn: genreColumn,
      platformColumn: platformColumn,
      statusColumn: statusColumn,
      playtimeColumn: playtimeColumn,
      ratingColumn: ratingColumn,
      completedAtColumn: completedAtColumn,
      noteColumns: noteColumns,
      reviewColumns: _toggled(reviewColumns, letter, on),
    );
  }

  CsvColumnConfig withNoteColumn(String letter, {required bool on}) {
    return CsvColumnConfig(
      titleColumn: titleColumn,
      genreColumn: genreColumn,
      platformColumn: platformColumn,
      statusColumn: statusColumn,
      playtimeColumn: playtimeColumn,
      ratingColumn: ratingColumn,
      completedAtColumn: completedAtColumn,
      noteColumns: _toggled(noteColumns, letter, on),
      reviewColumns: reviewColumns,
    );
  }
}

List<String> _toggled(List<String> letters, String letter, bool on) {
  final without = [
    for (final existing in letters)
      if (existing != letter) existing,
  ];
  return on ? [...without, letter] : without;
}

/// An entry of the backlog that a row of the file would duplicate, with what
/// the import would change on it.
class CsvDuplicate {
  const CsvDuplicate({
    required this.entryId,
    required this.title,
    required this.diffs,
  });

  factory CsvDuplicate.fromJson(Map<String, dynamic> json) {
    return CsvDuplicate(
      entryId: json['backlog_entry_id'] as int,
      title: json['title'] as String,
      diffs: [
        for (final diff in json['diffs'] as List<dynamic>)
          FieldDiffEntry(
            field: (diff as Map<String, dynamic>)['field'] as String,
            existing: diff['existing'] as String,
            proposed: diff['proposed'] as String,
          ),
      ],
    );
  }

  final int entryId;
  final String title;
  final List<FieldDiffEntry> diffs;
}

double? _number(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value as String);
}

String? _decimal(double? value) {
  if (value == null) return null;
  return value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();
}

/// One row of the import preview: what submitting it would create.
class CsvPreviewRow {
  const CsvPreviewRow({
    required this.rowIndex,
    required this.title,
    required this.genre,
    required this.platform,
    required this.status,
    required this.owned,
    this.playtime,
    this.reviewStars,
    this.note,
    this.review,
    this.completedAt,
    this.imageLink,
    this.description,
    this.trailerLink,
    this.mainTime,
    this.mainPlusExtraTime,
    this.completionTime,
    this.matched = false,
    this.duplicates = const [],
  });

  factory CsvPreviewRow.fromJson(Map<String, dynamic> json) {
    final completedAt = json['completed_at'] as String?;
    return CsvPreviewRow(
      rowIndex: json['row_index'] as int,
      title: json['title'] as String,
      genre: json['genre'] as String,
      platform: (json['platform'] as List<dynamic>).cast<String>(),
      status: json['status'] as String,
      owned: json['owned'] as bool,
      playtime: _number(json['playtime']),
      reviewStars: (json['review_stars'] as num?)?.toInt(),
      note: json['note'] as String?,
      review: json['review'] as String?,
      completedAt: completedAt == null
          ? null
          : serverTimeAsUtc(DateTime.parse(completedAt)),
      imageLink: json['image_link'] as String?,
      description: json['description'] as String?,
      trailerLink: json['trailer_link'] as String?,
      mainTime: _number(json['main_time']),
      mainPlusExtraTime: _number(json['main_plus_extra_time']),
      completionTime: _number(json['completion_time']),
      matched: json['matched'] as bool,
      duplicates: [
        for (final duplicate in json['duplicates'] as List<dynamic>)
          CsvDuplicate.fromJson(duplicate as Map<String, dynamic>),
      ],
    );
  }

  final int rowIndex;
  final String title;
  final String genre;
  final List<String> platform;
  final String status;
  final bool owned;
  final double? playtime;
  final int? reviewStars;
  final String? note;
  final String? review;
  final DateTime? completedAt;
  final String? imageLink;
  final String? description;
  final String? trailerLink;
  final double? mainTime;
  final double? mainPlusExtraTime;
  final double? completionTime;

  /// Whether the game was found in HowLongToBeat; a row that was not found
  /// needs a look from the user.
  final bool matched;
  final List<CsvDuplicate> duplicates;

  CsvPreviewRow copyWith({
    String? title,
    String? genre,
    List<String>? platform,
    String? status,
    bool? owned,
    String? imageLink,
  }) {
    return CsvPreviewRow(
      rowIndex: rowIndex,
      title: title ?? this.title,
      genre: genre ?? this.genre,
      platform: platform ?? this.platform,
      status: status ?? this.status,
      owned: owned ?? this.owned,
      playtime: playtime,
      reviewStars: reviewStars,
      note: note,
      review: review,
      completedAt: completedAt,
      imageLink: imageLink ?? this.imageLink,
      description: description,
      trailerLink: trailerLink,
      mainTime: mainTime,
      mainPlusExtraTime: mainPlusExtraTime,
      completionTime: completionTime,
      matched: matched,
      duplicates: duplicates,
    );
  }

  /// The row as an entry of the submit request.
  Map<String, Object?> toSubmitJson() {
    return {
      'title': title,
      'genre': genre,
      'platform': platform,
      'status': status,
      'owned': owned,
      'playtime': _decimal(playtime),
      'review_stars': reviewStars,
      'note': note,
      'review': review,
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'image_link': imageLink,
      'description': description,
      'trailer_link': trailerLink,
      'main_time': _decimal(mainTime),
      'main_plus_extra_time': _decimal(mainPlusExtraTime),
      'completion_time': _decimal(completionTime),
    };
  }
}

/// The platforms typed into a field: separated by commas, blanks dropped.
List<String> platformsFromText(String text) {
  return [
    for (final part in text.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}

/// The row after the user chose the right game: the game's data replaces the
/// title, cover, description, trailer and times, the genres only when the
/// game has some, and the row counts as matched.
CsvPreviewRow applyWrongGame(CsvPreviewRow row, GameSearchResult result) {
  return CsvPreviewRow(
    rowIndex: row.rowIndex,
    title: result.title,
    genre: result.genres.isEmpty ? row.genre : result.genres.join(', '),
    platform: row.platform,
    status: row.status,
    owned: row.owned,
    playtime: row.playtime,
    reviewStars: row.reviewStars,
    note: row.note,
    review: row.review,
    completedAt: row.completedAt,
    imageLink: result.imageUrl,
    description: result.description,
    trailerLink: result.trailerUrl,
    mainTime: result.mainStory,
    mainPlusExtraTime: result.mainStoryWithExtras,
    completionTime: result.completionist,
    matched: true,
    duplicates: row.duplicates,
  );
}

/// The button a row of the preview offers.
enum RowAction {
  cover('Cover'),
  wrongGame('Wrong game');

  const RowAction(this.label);

  final String label;
}

/// The chip and the button of a row: a row that was not matched asks for the
/// right game, otherwise the first thing that is missing is named.
({String? chip, RowAction action}) rowVerdict(CsvPreviewRow row) {
  if (!row.matched) return (chip: 'Check match', action: RowAction.wrongGame);
  if (row.mainTime == null) {
    return (chip: 'No beat times', action: RowAction.cover);
  }
  if (row.imageLink == null || row.imageLink!.isEmpty) {
    return (chip: 'No cover', action: RowAction.cover);
  }
  return (chip: row.owned ? 'Owned' : null, action: RowAction.cover);
}

/// What the info line of a row warns about.
List<String> rowWarnings(CsvPreviewRow row) {
  return [
    if (row.imageLink == null || row.imageLink!.isEmpty) 'No cover found',
    if (row.mainTime == null) 'No beat times found',
  ];
}

/// "RPG · PC · Playing", leaving out what the row does not have.
String rowMeta(CsvPreviewRow row) {
  return [
    if (row.genre.isNotEmpty) row.genre,
    if (row.platform.isNotEmpty) row.platform.join(', '),
    row.status,
  ].join(' · ');
}

String _plural(int count, String one, String many) =>
    '$count ${count == 1 ? one : many}';

/// "312 rows - 18 already in your backlog".
String rowsSummary(List<CsvPreviewRow> rows) {
  final duplicates = rows.where((row) => row.duplicates.isNotEmpty).length;
  final count = _plural(rows.length, 'row', 'rows');
  return duplicates == 0
      ? count
      : '$count - $duplicates already in your backlog';
}

String importLabel(int count) => 'Import ${_plural(count, 'game', 'games')}';

String previewLabel(int? processed, int? total) {
  if (processed == null || total == null) return 'Loading preview...';
  return 'Loading $processed/$total...';
}

String submitLabel(int? processed, int? total) {
  if (processed == null || total == null) return 'Importing...';
  return 'Importing $processed/$total...';
}

/// The toast after an import.
String importResultMessage(int created, int skipped) {
  final done =
      'Imported ${_plural(created, 'backlog entry', 'backlog entries')}';
  return skipped > 0 ? '$done, skipped $skipped' : done;
}

String skippedHeading(int count) =>
    '${_plural(count, 'row', 'rows')} skipped during import';

/// "A: Game", or just the letter for a column without a header.
String columnLabel(String letter, Map<String, String> headers) {
  final header = headers[letter];
  return header == null || header.isEmpty ? letter : '$letter: $header';
}

/// The column letters of the file in spreadsheet order (A, B, ... Z, AA).
List<String> sortedColumnLetters(Map<String, String> headers) {
  return headers.keys.toList()..sort((a, b) {
    final byLength = a.length.compareTo(b.length);
    return byLength != 0 ? byLength : a.compareTo(b);
  });
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "March 2025".
String completedMonthLabel(DateTime date) =>
    '${_months[date.month - 1]} ${date.year}';

/// The largest file the import accepts: the server refuses bigger requests.
const maxCsvBytes = 10 * 1024 * 1024;

/// A file that cannot be imported; [message] says why.
class CsvFileException implements Exception {
  const CsvFileException(this.message);

  final String message;

  @override
  String toString() => 'CsvFileException: $message';
}

/// The text of a chosen file, or a [CsvFileException] for a file that is not
/// a CSV file, is empty, is too large or is not valid UTF-8 text. A leading
/// byte order mark is dropped.
String decodeCsvFile(String name, List<int> bytes) {
  if (!name.toLowerCase().endsWith('.csv')) {
    throw const CsvFileException('Choose a .csv file.');
  }
  if (bytes.isEmpty) throw const CsvFileException('That file is empty.');
  if (bytes.length > maxCsvBytes) {
    throw const CsvFileException('That file is too large (10 MB at most).');
  }
  try {
    final text = utf8.decode(bytes);
    return text.startsWith('\uFEFF') ? text.substring(1) : text;
  } on FormatException {
    throw const CsvFileException('That file is not valid UTF-8 text.');
  }
}
