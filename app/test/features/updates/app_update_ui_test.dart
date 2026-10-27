import 'dart:async';
import 'dart:io';

import 'package:backlog_manager/data/release_source.dart';
import 'package:backlog_manager/data/update_channel.dart';
import 'package:backlog_manager/data/update_download.dart';
import 'package:backlog_manager/domain/app_update.dart';
import 'package:backlog_manager/features/updates/app_update_state.dart';
import 'package:backlog_manager/platform/update_installer.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../../data/update_channel_test.dart' show MemoryChannelStore;
import '../library/library_page_test.dart' show backlog, pumpLibrary;
import '../settings/settings_page_test.dart' show openSettings;
import 'app_update_install_test.dart'
    show FakeDownloader, FakeInstaller, signedRelease;

class FakeSource implements ReleaseSource {
  FakeSource({this.release, this.fail = false});

  AppRelease? release;
  bool fail;
  Completer<void>? gate;
  var calls = 0;

  @override
  Future<AppRelease?> latest() async {
    calls++;
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
  group('the update channel', () {
    List<Override> overrides(FakeSource source, MemoryChannelStore store) => [
      ...updateOverrides(source),
      updateChannelStoreProvider.overrideWithValue(store),
    ];

    testWidgets('offers Stable and Preview, Preview being the default', (
      tester,
    ) async {
      await openSettings(
        tester,
        location: '/settings?tab=updates',
        overrides: overrides(FakeSource(), MemoryChannelStore()),
      );

      expect(find.text('Update Channel'), findsOneWidget);
      expect(find.text('Stable'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
    });

    testWidgets('choosing Stable keeps it and checks for an update again', (
      tester,
    ) async {
      final source = FakeSource(release: releaseOf('0.9.3'));
      final store = MemoryChannelStore();
      await openSettings(
        tester,
        location: '/settings?tab=updates',
        overrides: overrides(source, store),
      );
      expect(source.calls, 0);

      await tester.tap(find.text('Stable'));
      await tester.pumpAndSettle();

      expect(store.saved, UpdateChannel.stable);
      expect(source.calls, 1);
      expect(find.text('You are on the latest version.'), findsOneWidget);
    });

    testWidgets('says what the channels are', (tester) async {
      await openSettings(
        tester,
        location: '/settings?tab=updates',
        overrides: overrides(FakeSource(), MemoryChannelStore()),
      );

      expect(find.textContaining('pre-releases'), findsOneWidget);
    });
  });

  group('the About tab', () {
    testWidgets('reports that the app is up to date', (tester) async {
      await openSettings(
        tester,
        location: '/settings?tab=updates',
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
        location: '/settings?tab=updates',
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
        location: '/settings?tab=updates',
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

    testWidgets(
      'offers the older newest release of the channel to go back to',
      (tester) async {
        final settings = await openSettings(
          tester,
          location: '/settings?tab=updates',
          overrides: updateOverrides(
            FakeSource(release: releaseOf('0.9.2', notes: 'Old notes')),
          ),
        );

        await tester.tap(find.byKey(const Key('check-for-updates')));
        await tester.pumpAndSettle();

        expect(find.text('You are on the latest version.'), findsNothing);
        expect(
          find.text('You are ahead of the newest Stable release (0.9.2).'),
          findsOneWidget,
        );
        expect(find.text('Old notes'), findsNothing);
        expect(find.text('View 0.9.2'), findsOneWidget);

        await tester.tap(find.byKey(const Key('view-release')));
        await tester.pump();
        expect(settings.opened.single.path, endsWith('/releases/tag/v0.9.2'));
      },
    );

    testWidgets('names the channel that was chosen', (tester) async {
      await openSettings(
        tester,
        location: '/settings?tab=updates',
        overrides: [
          ...updateOverrides(FakeSource(release: releaseOf('0.9.2'))),
          updateChannelStoreProvider.overrideWithValue(MemoryChannelStore()),
        ],
      );

      await tester.tap(find.text('Stable'));
      await tester.pumpAndSettle();

      expect(
        find.text('You are ahead of the newest Stable release (0.9.2).'),
        findsOneWidget,
      );
    });

    testWidgets('reports a failed check', (tester) async {
      await openSettings(
        tester,
        location: '/settings?tab=updates',
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

      await tester.tap(find.text('View Release'));
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

  group('going back to an older release', () {
    testWidgets('installs it in place and restarts into it', (tester) async {
      final signed = (await tester.runAsync(
        () => signedRelease(version: '0.9.2'),
      ))!;
      final content = List<int>.generate(2000, (i) => i % 251);
      final dir = Directory.systemTemp.createTempSync('blm-ui-downgrade-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final installer = FakeInstaller(dir);
      var exited = 0;
      await openSettings(
        tester,
        location: '/settings?tab=updates',
        overrides: [
          ...updateOverrides(FakeSource(release: signed.release)),
          updateInstallerProvider.overrideWithValue(installer),
          updateVerifierProvider.overrideWithValue(signed.verifier),
          updateDownloaderProvider.overrideWithValue(FakeDownloader(content)),
          appExitProvider.overrideWithValue(() => exited++),
        ],
      );

      await tester.tap(find.byKey(const Key('check-for-updates')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('view-release')), findsNothing);
      expect(find.text('Switch to 0.9.2'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('downgrade-update')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('restart-update')), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('restart-update')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(installer.applied, hasLength(1));
      expect(exited, 1);
    });

    testWidgets('is not announced when the app starts', (tester) async {
      final container = await pumpLibrary(
        tester,
        FakeBacklogApi(entries: backlog),
        overrides: [
          ...updateOverrides(FakeSource(release: releaseOf('0.9.2'))),
          automaticUpdateCheckProvider.overrideWithValue(true),
        ],
      );

      expect(
        container.read(appUpdateProvider).check,
        UpdateCheck.older,
        reason: 'the check has finished and found the older release',
      );
      expect(find.textContaining('is available'), findsNothing);
      expect(find.textContaining('0.9.2'), findsNothing);
    });

    testWidgets('a failed switch says so and can be tried again', (
      tester,
    ) async {
      final signed = (await tester.runAsync(
        () => signedRelease(version: '0.9.2'),
      ))!;
      final dir = Directory.systemTemp.createTempSync('blm-ui-downgrade-');
      addTearDown(() => dir.deleteSync(recursive: true));
      await openSettings(
        tester,
        location: '/settings?tab=updates',
        overrides: [
          ...updateOverrides(FakeSource(release: signed.release)),
          updateInstallerProvider.overrideWithValue(FakeInstaller(dir)),
          updateVerifierProvider.overrideWithValue(signed.verifier),
          updateDownloaderProvider.overrideWithValue(
            FakeDownloader([1, 2, 3], fail: true),
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('check-for-updates')));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('downgrade-update')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('update-error')), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.byKey(const Key('downgrade-update')), findsOneWidget);
    });
  });

  group('an update that can be installed in place', () {
    testWidgets('installs from the About tab and restarts into it', (
      tester,
    ) async {
      final signed = (await tester.runAsync(signedRelease))!;
      final content = List<int>.generate(2000, (i) => i % 251);
      final dir = Directory.systemTemp.createTempSync('blm-ui-update-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final installer = FakeInstaller(dir);
      var exited = 0;
      await openSettings(
        tester,
        location: '/settings?tab=updates',
        overrides: [
          ...updateOverrides(FakeSource(release: signed.release)),
          updateInstallerProvider.overrideWithValue(installer),
          updateVerifierProvider.overrideWithValue(signed.verifier),
          updateDownloaderProvider.overrideWithValue(FakeDownloader(content)),
          appExitProvider.overrideWithValue(() => exited++),
        ],
      );

      await tester.tap(find.byKey(const Key('check-for-updates')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('view-release')), findsNothing);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('install-update')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('restart-update')), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('restart-update')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(installer.applied, hasLength(1));
      expect(exited, 1);
    });
  });
}
