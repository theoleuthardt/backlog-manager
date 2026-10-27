import 'package:backlog_manager/features/appearance/theme_preview.dart';
import 'package:backlog_manager/platform/desktop.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'settings_page_test.dart' show openSettings;

const phone = Size(402, 874);
const handheld = Size(732, 412);

Future<void> openOn(WidgetTester tester, Size size, {String? location}) =>
    openSettings(
      tester,
      size: size,
      location: location ?? AppRoutes.settings,
      overrides: [isDesktopProvider.overrideWithValue(false)],
    );

void main() {
  group('settings on a phone', () {
    testWidgets('opens the list of tabs', (tester) async {
      await openOn(tester, phone);

      for (final id in [
        'general',
        'security',
        'integrations',
        'backups',
        'updates',
        'about',
      ]) {
        expect(find.byKey(Key('settings-tab-$id')), findsOneWidget, reason: id);
      }
      expect(find.byKey(const Key('settings-account')), findsOneWidget);
      expect(find.byKey(const Key('settings-tab-content')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tab opens on its own and goes back to the list', (
      tester,
    ) async {
      await openOn(tester, phone);

      await tester.tap(find.byKey(const Key('settings-tab-integrations')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-tab-content')), findsOneWidget);
      expect(find.byKey(const Key('settings-steam-id')), findsOneWidget);
      expect(find.byKey(const Key('settings-tab-general')), findsNothing);

      await tester.tap(find.byKey(const Key('settings-tabs-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-tab-general')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the system back of a tab goes back to the list', (
      tester,
    ) async {
      await openOn(tester, phone);
      await tester.tap(find.byKey(const Key('settings-tab-security')));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-tab-general')), findsOneWidget);
      expect(find.byKey(const Key('settings-tab-content')), findsNothing);
    });

    testWidgets('a tab from the address opens directly', (tester) async {
      await openOn(tester, phone, location: '/settings?tab=about');

      expect(find.byKey(const Key('settings-tab-content')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final id in [
      'general',
      'security',
      'integrations',
      'backups',
      'updates',
      'about',
    ]) {
      testWidgets('the $id tab fits the screen', (tester) async {
        await openOn(tester, phone, location: '/settings?tab=$id');
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('settings on a handheld', () {
    testWidgets('keeps the tabs beside the content and fits the height', (
      tester,
    ) async {
      await openOn(tester, handheld);

      expect(find.byKey(const Key('settings-tab-general')), findsOneWidget);
      expect(find.byKey(const Key('settings-tab-content')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('appearance on small screens', () {
    for (final (name, size) in [('phone', phone), ('handheld', handheld)]) {
      testWidgets('stacks the list, the editor and the preview on a $name', (
        tester,
      ) async {
        await openOn(tester, size, location: AppRoutes.appearance);

        final list = tester.getTopLeft(find.byKey(const Key('theme-none')));
        final editor = tester.getTopLeft(find.byKey(const Key('theme-name')));
        final preview = tester.getTopLeft(find.byType(ThemePreview));
        expect(editor.dy, greaterThan(list.dy));
        expect(preview.dy, greaterThan(editor.dy));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
