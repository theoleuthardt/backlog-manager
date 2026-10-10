import 'package:backlog_manager/domain/format.dart';

/// Where a Steam preview comes from.
enum SteamSource { library, wishlist }

double? _number(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value as String);
}

/// One game of a Steam preview. [playtime] is in hours; the library preview
/// reports it, the wishlist preview has none.
class SteamRow {
  const SteamRow({
    required this.steamAppId,
    required this.title,
    this.imageLink,
    this.playtime,
  });

  factory SteamRow.fromJson(Map<String, dynamic> json) {
    return SteamRow(
      steamAppId: json['steam_app_id'] as int,
      title: json['title'] as String,
      imageLink: json['image_link'] as String?,
      playtime: _number(json['playtime']),
    );
  }

  final int steamAppId;
  final String title;
  final String? imageLink;
  final double? playtime;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The day of the first wishlist import as shown on the Steam page
/// ("10 Oct 2026"), or null when the wishlist was never imported. The wishlist
/// import is for the first time only: once this has a date the page no longer
/// offers it.
String? wishlistImportDate(DateTime? importedAt) {
  if (importedAt == null) return null;
  final day = importedAt.toUtc();
  return '${day.day} ${_months[day.month - 1]} ${day.year}';
}

/// The warning when a wishlist import created fewer entries than the preview
/// listed because the Steam store could not name some games right now; they
/// are left out rather than imported under their app id, and the import stays
/// available for another try. Null when nothing was left out.
String? skippedWishlistMessage(int previewed, int created) {
  final skipped = previewed - created;
  if (skipped <= 0) return null;
  final games = skipped == 1 ? 'game' : 'games';
  final verb = skipped == 1 ? 'was' : 'were';
  return '$skipped $games could not be named by Steam right now and $verb '
      'left out - try the import again later';
}

String _games(int count) => '$count ${count == 1 ? 'game' : 'games'}';

/// "24 new games from your library".
String previewHeading(SteamSource source, int count) {
  final from = source == SteamSource.library ? 'library' : 'wishlist';
  return '$count new ${count == 1 ? 'game' : 'games'} from your $from';
}

/// "1,284 of 1,284 checked", or "Checking..." before the first progress.
String checkedLine(int? processed, int? total) {
  if (processed == null || total == null) return 'Checking...';
  return '${formatCount(processed)} of ${formatCount(total)} checked';
}

String selectedLabel(int selected, int total) => '$selected of $total selected';

String steamImportLabel(int count) => 'Import ${_games(count)}';

/// The playtime of a row, empty when the server did not send one.
String steamHoursLabel(double? hours) {
  if (hours == null) return '';
  return '${formatHours(hours)} h';
}

/// The toast after an import.
String importedMessage(SteamSource source, int created) {
  if (created == 0) {
    return 'No new games to import, your backlog already has everything';
  }
  final from = source == SteamSource.library ? 'library' : 'wishlist';
  return 'Imported ${_games(created)} from your Steam $from';
}

/// The toast after the playtime sync.
String playtimeSyncMessage(int updated) {
  if (updated == 0) return 'Steam is already up to date';
  return 'Synced ${_games(updated)} from Steam';
}

/// The tooltip of the playtime sync button with the exact count.
String playtimeSyncTooltip(
  int? processed,
  int? total, {
  required bool running,
}) {
  if (!running) return 'Sync Steam playtimes';
  if (processed == null || total == null) return 'Syncing playtimes...';
  return 'Syncing playtimes $processed/$total';
}

/// The rows whose title or Steam App ID contains [query]; a blank query keeps
/// all of them.
List<SteamRow> filterSteamRows(List<SteamRow> rows, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return rows;
  return [
    for (final row in rows)
      if (row.title.toLowerCase().contains(needle) ||
          '${row.steamAppId}'.contains(needle))
        row,
  ];
}
