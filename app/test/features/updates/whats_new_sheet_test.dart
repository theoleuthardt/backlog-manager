import 'package:backlog_manager/data/release_source.dart';
import 'package:backlog_manager/data/whats_new.dart';
import 'package:backlog_manager/features/updates/whats_new_sheet.dart';
import 'package:backlog_manager/platform/desktop.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../../data/whats_new_store_test.dart'
    show FakeNotesSource, MemoryWhatsNewStore;
import '../../design/widgets/harness.dart';
import '../home/home_page_test.dart' show pumpHome;

Future<MemoryWhatsNewStore> openHome(
  WidgetTester tester, {
  String? lastSeen = '0.9.17',
  List<Uri>? opened,
  bool desktop = true,
}) async {
  whatsNewEnabled = true;
  addTearDown(() => whatsNewEnabled = false);
  final store = MemoryWhatsNewStore(lastSeen);
  await pumpHome(
    tester,
    FakeBacklogApi(),
    overrides: [
      installedVersionProvider.overrideWith((ref) async => '0.9.18'),
      whatsNewStoreProvider.overrideWithValue(store),
      releaseNotesSourceProvider.overrideWithValue(
        FakeNotesSource(
          notes:
              "## What's Changed\n"
              '* feat(app): a new thing by @theo-claude in https://github.com/x\n'
              '* fix: a fixed thing\n',
        ),
      ),
      if (opened != null) urlOpenerProvider.overrideWithValue(opened.add),
      if (!desktop) isDesktopProvider.overrideWithValue(false),
    ],
  );
  return store;
}

void main() {
  goldenInBothThemes(
    'whats_new_sheet',
    () => ProviderScope(
      child: WhatsNewSheet(
        news: WhatsNew(
          version: '0.9.18',
          changes: const [
            'Gliding focus selector after DroidDeck',
            'The search keyboard only opens after A on a controller',
            'What is new shows once after an update',
          ],
          pageUrl: Uri.parse('https://github.com/x/y/releases/tag/v0.9.18'),
        ),
      ),
    ),
    size: const Size(620, 420),
  );

  testWidgets('shows what is new after an update, once', (tester) async {
    final store = await openHome(tester);

    expect(find.text("What's New in 0.9.18"), findsOneWidget);
    expect(find.text('A new thing'), findsOneWidget);
    expect(find.text('A fixed thing'), findsOneWidget);

    await tester.tap(find.byKey(const Key('whats-new-done')));
    await tester.pumpAndSettle();

    expect(find.text("What's New in 0.9.18"), findsNothing);
    expect(store.version, '0.9.18');
  });

  testWidgets('the release notes open the release page', (tester) async {
    final opened = <Uri>[];
    await openHome(tester, opened: opened);

    await tester.tap(find.byKey(const Key('whats-new-release')));
    await tester.pumpAndSettle();

    expect(opened.single.path, endsWith('/v0.9.18'));
  });

  testWidgets('a first install shows nothing', (tester) async {
    final store = await openHome(tester, lastSeen: null);

    expect(find.textContaining("What's New"), findsNothing);
    expect(store.version, '0.9.18');
  });

  testWidgets('fits a phone', (tester) async {
    await openHome(tester, desktop: false);
    tester.view.physicalSize = const Size(402, 874);
    await tester.pumpAndSettle();

    expect(find.text('A new thing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
