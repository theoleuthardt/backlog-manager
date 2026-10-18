import 'package:backlog_manager/domain/entry_mod.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import 'entry_inspector_test.dart' show hades, openInspector, openTab;

const _coop = EntryMod(
  id: 7,
  name: 'Better Co-op',
  url: 'https://www.nexusmods.com/mod/1',
);

Future<FakeBacklogApi> open(
  WidgetTester tester, {
  List<EntryMod> mods = const [],
  List<Uri>? opened,
}) async {
  final api = FakeBacklogApi(entries: const [hades])
    ..mods = {
      1: [...mods],
    };
  await openInspector(
    tester,
    backlog: api,
    overrides: [
      if (opened != null) urlOpenerProvider.overrideWithValue(opened.add),
    ],
  );
  await openTab(tester, 'Mods');
  return api;
}

void main() {
  testWidgets('shows an empty state without mods', (tester) async {
    await open(tester);

    expect(find.byKey(const Key('mods-empty')), findsOneWidget);
    expect(find.byKey(const Key('mod-add')), findsOneWidget);
  });

  testWidgets('lists the mods of the game with their links', (tester) async {
    await open(
      tester,
      mods: [
        _coop,
        const EntryMod(id: 8, name: 'Tweaks'),
      ],
    );

    expect(find.text('Better Co-op'), findsOneWidget);
    expect(find.text('Tweaks'), findsOneWidget);
    expect(find.byKey(const Key('mod-link-7')), findsOneWidget);
    expect(find.byKey(const Key('mod-link-8')), findsNothing);
  });

  testWidgets('a tap on the link opens it', (tester) async {
    final opened = <Uri>[];
    await open(tester, mods: [_coop], opened: opened);

    await tester.tap(find.byKey(const Key('mod-link-7')));
    await tester.pumpAndSettle();

    expect(opened, [Uri.parse('https://www.nexusmods.com/mod/1')]);
  });

  testWidgets('adds a mod with a name and a link', (tester) async {
    final api = await open(tester);

    await tester.tap(find.byKey(const Key('mod-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('mod-name')), 'Better Co-op');
    await tester.enterText(
      find.byKey(const Key('mod-url')),
      'https://example.com/m',
    );
    await tester.tap(find.byKey(const Key('mod-save')));
    await tester.pumpAndSettle();

    expect(api.calls, contains('add-mod 1 Better Co-op https://example.com/m'));
    expect(find.text('Better Co-op'), findsOneWidget);
    expect(find.byKey(const Key('mods-empty')), findsNothing);
  });

  testWidgets('does not add a mod with a bad link and says why', (
    tester,
  ) async {
    final api = await open(tester);

    await tester.tap(find.byKey(const Key('mod-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('mod-name')), 'Mod');
    await tester.enterText(find.byKey(const Key('mod-url')), 'javascript:x');
    await tester.tap(find.byKey(const Key('mod-save')));
    await tester.pumpAndSettle();

    expect(
      find.text('The link must start with http:// or https://'),
      findsOneWidget,
    );
    expect(api.calls.where((c) => c.startsWith('add-mod')), isEmpty);
  });

  testWidgets('edits a mod', (tester) async {
    final api = await open(tester, mods: [_coop]);

    await tester.tap(find.byKey(const Key('mod-edit-7')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('mod-name')), 'Co-op 2');
    await tester.enterText(find.byKey(const Key('mod-url')), '');
    await tester.tap(find.byKey(const Key('mod-save')));
    await tester.pumpAndSettle();

    expect(api.calls, contains('update-mod 1 7 Co-op 2 null'));
    expect(find.text('Co-op 2'), findsOneWidget);
    expect(find.byKey(const Key('mod-link-7')), findsNothing);
  });

  testWidgets('removes a mod', (tester) async {
    final api = await open(tester, mods: [_coop]);

    await tester.tap(find.byKey(const Key('mod-delete-7')));
    await tester.pumpAndSettle();

    expect(api.calls, contains('delete-mod 1 7'));
    expect(find.byKey(const Key('mods-empty')), findsOneWidget);
  });
}
