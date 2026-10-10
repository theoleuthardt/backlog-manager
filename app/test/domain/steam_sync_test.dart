import 'package:backlog_manager/domain/steam_sync.dart';
import 'package:flutter_test/flutter_test.dart';

SteamRow row(int id, String title, {double? playtime}) => SteamRow(
  steamAppId: id,
  title: title,
  imageLink: 'https://img/$id.jpg',
  playtime: playtime,
);

void main() {
  group('wishlistImportDate', () {
    test('is null while the wishlist was never imported', () {
      expect(wishlistImportDate(null), isNull);
    });

    test('formats the date of the first import', () {
      expect(
        wishlistImportDate(DateTime.utc(2026, 10, 10, 9, 30)),
        '10 Oct 2026',
      );
    });

    test('uses the UTC day', () {
      expect(
        wishlistImportDate(DateTime.utc(2026, 1, 2, 23, 30)),
        '2 Jan 2026',
      );
    });
  });

  group('skippedWishlistMessage', () {
    test('is null when every previewed game was imported', () {
      expect(skippedWishlistMessage(5, 5), isNull);
      expect(skippedWishlistMessage(0, 0), isNull);
    });

    test('names the number of games that were left out', () {
      expect(
        skippedWishlistMessage(5, 3),
        '2 games could not be named by Steam right now and were left out - '
        'try the import again later',
      );
    });

    test('uses the singular for one game', () {
      expect(
        skippedWishlistMessage(5, 4),
        '1 game could not be named by Steam right now and was left out - '
        'try the import again later',
      );
    });
  });

  group('SteamRow.fromJson', () {
    test('reads the fields of a preview item', () {
      final parsed = SteamRow.fromJson({
        'steam_app_id': 620,
        'title': 'Portal 2',
        'image_link': 'https://img/620.jpg',
        'playtime': '11.5',
      });

      expect(parsed.steamAppId, 620);
      expect(parsed.title, 'Portal 2');
      expect(parsed.imageLink, 'https://img/620.jpg');
      expect(parsed.playtime, 11.5);
    });

    test('copes with a server that sends no playtime', () {
      final parsed = SteamRow.fromJson({
        'steam_app_id': 1,
        'title': 'X',
        'image_link': null,
      });

      expect(parsed.imageLink, isNull);
      expect(parsed.playtime, isNull);
    });

    test('reads a playtime sent as a number', () {
      expect(
        SteamRow.fromJson({'steam_app_id': 1, 'title': 'X', 'playtime': 3})
            .playtime,
        3,
      );
    });
  });

  group('labels', () {
    test('the heading names the number and the source', () {
      expect(
        previewHeading(SteamSource.library, 24),
        '24 new games from your library',
      );
      expect(
        previewHeading(SteamSource.wishlist, 1),
        '1 new game from your wishlist',
      );
    });

    test('the checked line', () {
      expect(checkedLine(1284, 1284), '1,284 of 1,284 checked');
      expect(checkedLine(null, null), 'Checking...');
    });

    test('the selection', () {
      expect(selectedLabel(21, 24), '21 of 24 selected');
      expect(steamImportLabel(21), 'Import 21 games');
      expect(steamImportLabel(1), 'Import 1 game');
      expect(steamImportLabel(0), 'Import 0 games');
    });

    test('the playtime column', () {
      expect(steamHoursLabel(null), '');
      expect(steamHoursLabel(0), '0 h');
      expect(steamHoursLabel(11), '11 h');
      expect(steamHoursLabel(3.2), '3.2 h');
    });

    test('the result of an import', () {
      expect(
        importedMessage(SteamSource.library, 3),
        'Imported 3 games from your Steam library',
      );
      expect(
        importedMessage(SteamSource.wishlist, 1),
        'Imported 1 game from your Steam wishlist',
      );
      expect(
        importedMessage(SteamSource.library, 0),
        'No new games to import, your backlog already has everything',
      );
    });

    test('the result of the playtime sync', () {
      expect(playtimeSyncMessage(2), 'Synced 2 games from Steam');
      expect(playtimeSyncMessage(1), 'Synced 1 game from Steam');
      expect(playtimeSyncMessage(0), 'Steam is already up to date');
    });

    test('the tooltip of the playtime sync', () {
      expect(
        playtimeSyncTooltip(null, null, running: false),
        'Sync Steam playtimes',
      );
      expect(
        playtimeSyncTooltip(null, null, running: true),
        'Syncing playtimes...',
      );
      expect(
        playtimeSyncTooltip(3, 10, running: true),
        'Syncing playtimes 3/10',
      );
    });
  });

  group('filterSteamRows', () {
    final rows = [row(620, 'Portal 2'), row(1091500, 'Cyberpunk 2077')];

    test('keeps all rows for a blank query', () {
      expect(filterSteamRows(rows, '  '), rows);
    });

    test('matches the title without regard to case', () {
      expect(filterSteamRows(rows, 'PORTAL').map((r) => r.steamAppId), [620]);
    });

    test('matches the app id', () {
      expect(filterSteamRows(rows, '1091').map((r) => r.steamAppId), [1091500]);
    });
  });
}
