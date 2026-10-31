import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/inspector/trailer_sheet.dart';
import 'package:backlog_manager/platform/desktop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design/widgets/harness.dart';
import 'entry_inspector_test.dart' show openInspector;

final _mobile = [isDesktopProvider.overrideWithValue(false)];

const _manyGenres = BacklogEntry(
  id: 1,
  title: 'Cyberpunk 2077',
  genre: ['Shooter', 'Role-playing (RPG)', 'Adventure'],
  platform: ['PC', 'PlayStation 5', 'Xbox Series X|S'],
);

Future<void> openOn(WidgetTester tester, Size size) async {
  await openInspector(tester, entries: const [_manyGenres], overrides: _mobile);
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a phone has no full screen button', (tester) async {
    await openOn(tester, const Size(402, 874));

    expect(find.byKey(const Key('inspector-fullscreen')), findsNothing);
    expect(find.byKey(const Key('inspector-close')), findsOneWidget);
  });

  testWidgets('the desktop keeps it', (tester) async {
    await openInspector(tester, entries: const [_manyGenres]);

    expect(find.byKey(const Key('inspector-fullscreen')), findsOneWidget);
  });

  testWidgets('the platforms are not cut off by the genres', (tester) async {
    await openOn(tester, const Size(402, 874));

    final platforms = find.byKey(const Key('inspector-platforms'));
    expect(platforms, findsOneWidget);
    final chips = tester.getRect(platforms);
    final status = tester.getRect(find.byKey(const Key('status-select')));
    expect(chips.bottom, lessThanOrEqualTo(status.top));
    expect(find.text('PC'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the "+n" chip sits on the line of the other chips', (
    tester,
  ) async {
    await openOn(tester, const Size(402, 874));

    final more = find.byKey(const Key('genre-more'));
    if (more.evaluate().isEmpty) return;
    final shooter = tester.getCenter(find.text('Shooter'));
    expect(tester.getCenter(more).dy, closeTo(shooter.dy, 2));
  });

  testWidgets('a short handheld has Delete in the header, no footer', (
    tester,
  ) async {
    await openOn(tester, const Size(732, 412));

    final header = tester.getRect(find.byKey(const Key('inspector-close')));
    final delete = tester.getRect(find.byKey(const Key('inspector-delete')));
    expect(delete.center.dy, closeTo(header.center.dy, 1));
    final inspector = tester.getRect(find.byKey(const Key('entry-inspector')));
    final body = tester.getRect(
      find
          .descendant(
            of: find.byKey(const Key('entry-inspector')),
            matching: find.byType(SingleChildScrollView),
          )
          .first,
    );
    expect(inspector.bottom - body.bottom, lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone keeps Delete in the footer', (tester) async {
    await openOn(tester, const Size(402, 874));

    final close = tester.getRect(find.byKey(const Key('inspector-close')));
    final delete = tester.getRect(find.byKey(const Key('inspector-delete')));
    expect(delete.top, greaterThan(close.bottom + 100));
  });

  testWidgets('the handheld shows the details beside the tabs', (tester) async {
    await openOn(tester, const Size(732, 412));

    final status = tester.getRect(find.byKey(const Key('status-select')));
    final overview = tester.getRect(find.text('Overview'));
    expect(overview.left, greaterThan(status.right - 1));
    expect(tester.takeException(), isNull);
  });

  group('the trailer', () {
    Future<Rect> playerOn(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themed(
          'shelfOled',
          TrailerSheet(
            title: 'LEGO Batman',
            watchUrl: Uri.parse('https://www.youtube.com/watch?v=abcdefghijk'),
            player: const SizedBox.expand(),
          ),
          compact: size.width < 600,
          touch: true,
        ),
      );
      await tester.pumpAndSettle();
      return tester.getRect(find.byKey(const Key('trailer-player')));
    }

    testWidgets('takes the width of a phone', (tester) async {
      final player = await playerOn(tester, const Size(402, 874));

      expect(player.width, greaterThan(300));
      expect(player.right, lessThanOrEqualTo(402));
    });

    testWidgets('takes most of the height in landscape', (tester) async {
      final player = await playerOn(tester, const Size(732, 412));

      expect(player.height, greaterThan(250));
      expect(player.bottom, lessThanOrEqualTo(412));
    });
  });
}
