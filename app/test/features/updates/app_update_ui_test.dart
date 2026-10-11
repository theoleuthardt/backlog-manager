import 'dart:async';

import 'package:backlog_manager/data/release_source.dart';
import 'package:backlog_manager/domain/app_update.dart';
import 'package:backlog_manager/features/updates/app_update_state.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show backlog, pumpLibrary;
import '../settings/settings_page_test.dart' show openSettings;

class FakeSource implements ReleaseSource {
  FakeSource({this.release, this.fail = false});

  AppRelease? release;
  bool fail;
  Completer<void>? gate;

  @override
  Future<AppRelease?> latest() async {
    await gate?.future;
    if (fail) throw Exception('offline');
    return release;
  }
}

AppRelease releaseOf(String version, {String notes = ''}) => AppRelease(
  version: version,
  notes: notes,
  pageUrl: Uri.parse(
    'https://github.com/theoleuthardt/backlog-manager/releases/tag/v$version',
  ),
);

List<Override> updateOverrides(
  FakeSource source, {
  String installed = '0.9.3',
}) => [
  releaseSourceProvider.overrideWithValue(source),
  installedVersionProvider.overrideWith((ref) async => installed),
];

void main() {
  group('the About tab', () {
    testWidgets('reports that the app is up to date', (tester) async {
      await openSettings(
        tester,
        location: '/settings?tab=about',
        overrides: updateOverrides(FakeSource(release: releaseOf('0.9.3'))),
      );

      await tester.tap(find.byKey(const Key('check-for-updates')));
      await tester.pumpAndSettle();

      expect(find.text('You are on the latest version.'), findsOneWidget);
    });

    testWidgets('shows "Checking..." while the check runs', (tester) async {
      final source = FakeSource(release: releaseOf('0.9.3'))
        ..gate = Completer<void>();
      await openSettings(
        tester,
        location: '/settings?tab=about',
        overrides: updateOverrides(source),
      );

      await tester.tap(find.byKey(const Key('check-for-updates')));
      await tester.pump();
      expect(find.text('Checking...'), findsOneWidget);

      source.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Check for updates'), findsOneWidget);
    });

    testWidgets('offers the new release with its notes', (tester) async {
      final settings = await openSettings(
        tester,
        location: '/settings?tab=about',
        overrides: updateOverrides(
          FakeSource(release: releaseOf('0.9.4', notes: 'New: group order')),
        ),
      );

      await tester.tap(find.byKey(const Key('check-for-updates')));
      await tester.pumpAndSettle();

      expect(find.text('Version 0.9.4 is available.'), findsOneWidget);
      expect(find.text('New: group order'), findsOneWidget);

      await tester.tap(find.byKey(const Key('view-release')));
      await tester.pump();
      expect(settings.opened.single.path, endsWith('/releases/tag/v0.9.4'));
    });

    testWidgets('reports a failed check', (tester) async {
      await openSettings(
        tester,
        location: '/settings?tab=about',
        overrides: updateOverrides(FakeSource(fail: true)),
      );

      await tester.tap(find.byKey(const Key('check-for-updates')));
      await tester.pumpAndSettle();

      expect(
        find.text('The update check failed. Try again later.'),
        findsOneWidget,
      );
    });
  });

  group('the notification', () {
    testWidgets('shows once and opens the release page', (tester) async {
      final opened = <Uri>[];
      final container = await pumpLibrary(
        tester,
        FakeBacklogApi(entries: backlog),
        overrides: [
          ...updateOverrides(FakeSource(release: releaseOf('0.9.4'))),
          automaticUpdateCheckProvider.overrideWithValue(true),
          urlOpenerProvider.overrideWithValue(opened.add),
        ],
      );

      expect(find.text('Backlog Manager 0.9.4 is available'), findsOneWidget);

      await tester.tap(find.text('View release'));
      await tester.pumpAndSettle();
      expect(opened.single.path, endsWith('/releases/tag/v0.9.4'));

      await container.read(appUpdateProvider.notifier).check();
      await tester.pumpAndSettle();
      expect(find.text('Backlog Manager 0.9.4 is available'), findsNothing);
    });

    testWidgets('stays silent when the app is up to date or offline', (
      tester,
    ) async {
      await pumpLibrary(
        tester,
        FakeBacklogApi(entries: backlog),
        overrides: [
          ...updateOverrides(FakeSource(fail: true)),
          automaticUpdateCheckProvider.overrideWithValue(true),
        ],
      );

      expect(find.textContaining('is available'), findsNothing);
      expect(find.textContaining('failed'), findsNothing);
    });

    testWidgets('makes no request in development builds', (tester) async {
      final source = FakeSource(release: releaseOf('0.9.4'));
      await pumpLibrary(
        tester,
        FakeBacklogApi(entries: backlog),
        overrides: updateOverrides(source),
      );

      expect(find.textContaining('is available'), findsNothing);
    });
  });
}
