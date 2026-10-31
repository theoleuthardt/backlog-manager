import 'package:backlog_manager/data/backups_api.dart';
import 'package:backlog_manager/data/update_channel.dart';
import 'package:backlog_manager/features/appearance/theme_preview.dart';
import 'package:backlog_manager/platform/desktop.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/update_channel_test.dart' show MemoryChannelStore;
import '../updates/app_update_ui_test.dart'
    show FakeSource, releaseOf, updateOverrides;
import 'backups_tab_test.dart' show FakeBackupsApi, manual, named;
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
    for (final id in [
      'general',
      'security',
      'integrations',
      'backups',
      'updates',
      'about',
    ]) {
      testWidgets('the $id tab fits the screen', (tester) async {
        await openOn(tester, handheld, location: '/settings?tab=$id');
        expect(tester.takeException(), isNull);
      });
    }

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

  group('the tabs that overflowed on the devices (#556)', () {
    testWidgets('a backup keeps room for its name on a phone', (tester) async {
      await openSettings(
        tester,
        size: phone,
        location: '/settings?tab=backups',
        overrides: [
          isDesktopProvider.overrideWithValue(false),
          backupsApiProvider.overrideWithValue(FakeBackupsApi([manual, named])),
        ],
      );

      final name = find.textContaining('Before the move');
      expect(tester.getSize(name).width, greaterThan(150));
      final restore = tester.getRect(
        find.byKey(Key('backup-restore-${named.id}')),
      );
      expect(restore.top, greaterThanOrEqualTo(tester.getRect(name).bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the updates fit a phone with a long note', (tester) async {
      await openSettings(
        tester,
        size: phone,
        location: '/settings?tab=updates',
        overrides: [
          isDesktopProvider.overrideWithValue(false),
          ...updateOverrides(
            FakeSource(release: releaseOf('0.9.13')),
            installed: '0.9.15',
          ),
          updateChannelStoreProvider.overrideWithValue(MemoryChannelStore()),
        ],
      );
      await tester.tap(find.byKey(const Key('check-for-updates')));
      await tester.pumpAndSettle();

      expect(find.textContaining('You are ahead'), findsOneWidget);
      final view = find.byKey(const Key('view-release'));
      expect(tester.getRect(view).right, lessThanOrEqualTo(phone.width));
      expect(tester.takeException(), isNull);
    });

    for (final size in [handheld, const Size(960, 540)]) {
      testWidgets('the integrations keep their labels readable at $size', (
        tester,
      ) async {
        await openOn(tester, size, location: '/settings?tab=integrations');

        final caption = find.textContaining('Falls back to the server');
        final lineHeight = tester.getSize(find.text('Steam ID').first).height;
        expect(
          tester.getSize(caption.first).height,
          lessThanOrEqualTo(lineHeight * 3.5),
          reason: 'the description is not squeezed into a narrow column',
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
