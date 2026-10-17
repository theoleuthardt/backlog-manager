import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/features/library/library_view.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'filter_bar_test.dart' show backlog, pumpLibrary;

Future<void> loadAppFont() async {
  final loader = FontLoader('PlusJakartaSans');
  for (final file in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$file.ttf'));
  }
  await loader.load();
}

void main() {
  setUpAll(loadAppFont);

  group('in the smallest window with the details open', () {
    Future<void> shrink(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      tester.view.physicalSize = const Size(1000, 2400);
      container.read(routerProvider).go('/library?entry=1');
      await tester.pumpAndSettle();
    }

    void expectInside(WidgetTester tester, Finder control) {
      final bar = tester.getRect(find.byKey(const Key('filter-bar')));
      final rect = tester.getRect(control);
      expect(rect.left, greaterThanOrEqualTo(bar.left), reason: '$control');
      expect(rect.right, lessThanOrEqualTo(bar.right), reason: '$control');
    }

    testWidgets('keeps every control inside the bar', (tester) async {
      final container = await pumpLibrary(tester, backlog());

      await shrink(tester, container);

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('filter-bar'))).width,
        lessThan(450),
        reason: 'this is the narrow pane of the bug',
      );
      for (final control in [
        find.byKey(const Key('add-filter')),
        find.byKey(const Key('owned-only')),
        find.byTooltip('Sort Direction'),
        find.byKey(const Key('layout-toggle')),
      ]) {
        expect(control, findsOneWidget);
        expectInside(tester, control);
      }
    });

    testWidgets('still fits with a filter active and the Reset button', (
      tester,
    ) async {
      final container = await pumpLibrary(tester, backlog());
      container.read(filtersProvider.notifier).setOwnedOnly(true);
      await shrink(tester, container);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('filter-reset')), findsOneWidget);
      expectInside(tester, find.byKey(const Key('filter-reset')));
      expectInside(tester, find.byKey(const Key('add-filter')));
    });

    testWidgets('leaves the room of the tokens for the add button', (
      tester,
    ) async {
      final container = await pumpLibrary(tester, backlog());

      await shrink(tester, container);

      expect(
        tester.getSize(find.byKey(const Key('add-filter'))).width,
        greaterThan(60),
      );
    });

    testWidgets('the layout toggle switches between grid and list', (
      tester,
    ) async {
      final container = await pumpLibrary(tester, backlog());
      tester.view.physicalSize = const Size(760, 2400);
      await tester.pumpAndSettle();
      expect(container.read(libraryViewProvider).layout, LibraryLayout.grid);

      await tester.tap(find.byKey(const Key('layout-toggle')));
      await tester.pumpAndSettle();

      expect(container.read(libraryViewProvider).layout, LibraryLayout.list);
    });
  });
}
