import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show game, pumpLibrary;
import '../settings/settings_page_test.dart' show openSettings, theo;

/// Moves the focus to the control with [key] the way a user does, with Tab,
/// and presses Enter on it.
Future<void> activate(WidgetTester tester, Key key) async {
  final target = find.byKey(key);
  for (var presses = 0; presses < 120; presses++) {
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus != null) {
      var inside = false;
      focus.visitAncestorElements((element) {
        if (element.widget.key == key) inside = true;
        return !inside;
      });
      if (inside) break;
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(target, findsOneWidget);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

Future<void> openAppearance(WidgetTester tester) => openSettings(
  tester,
  user: SessionUser(
    name: theo.name,
    email: theo.email,
    setupCompleted: true,
    theme: 'shelfOled',
    customThemes: const [
      CustomTheme(
        id: 'custom-neon',
        name: 'Neon',
        colors: ThemeColors(
          background: '#0a0014',
          surface: '#1a0033',
          foreground: '#f5e9ff',
          accent: '#ff2bd6',
          border: '#5b2a86',
          glow: '#00e5ff',
        ),
      ),
    ],
  ),
  location: '/appearance',
);

void main() {
  testWidgets('a library group collapses with the keyboard', (tester) async {
    await pumpLibrary(
      tester,
      FakeBacklogApi(entries: [game(1, 'Hades', status: 'Playing')]),
    );
    expect(find.byKey(const Key('tile-1')), findsOneWidget);

    await activate(tester, const Key('group-toggle-status:Playing'));

    expect(find.byKey(const Key('tile-1')), findsNothing);
  });

  testWidgets('a library group is announced with its state', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpLibrary(
      tester,
      FakeBacklogApi(entries: [game(1, 'Hades', status: 'Playing')]),
    );

    final node = tester.getSemantics(
      find.byKey(const Key('group-toggle-status:Playing')),
    );

    expect(node.label, 'Playing, 1, expanded');
    handle.dispose();
  });

  testWidgets('a theme is picked with the keyboard', (tester) async {
    await openAppearance(tester);

    await activate(tester, const Key('theme-item-light'));

    expect(find.text('active'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('theme-item-light')),
        matching: find.text('active'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a theme is announced with its name and state', (tester) async {
    final handle = tester.ensureSemantics();
    await openAppearance(tester);

    expect(find.bySemanticsLabel('Shelf OLED, active'), findsOneWidget);
    expect(find.bySemanticsLabel('Light'), findsOneWidget);
    expect(find.bySemanticsLabel('Edit Neon'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete Neon'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('text follows the text scale of the system', (tester) async {
    await pumpLibrary(
      tester,
      FakeBacklogApi(entries: [game(1, 'Hades', status: 'Playing')]),
    );
    final normal = tester.getSize(find.text('Library').first).height;

    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.text('Library').first).height,
      greaterThan(normal),
    );
  });

  testWidgets('sheets do not slide when the system asks for less motion', (
    tester,
  ) async {
    await pumpLibrary(tester, FakeBacklogApi(entries: [game(1, 'Hades')]));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();

    await tester.tap(find.byKey(const Key('duplicates-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    final top = tester.getTopLeft(find.byKey(const Key('sheet-surface'))).dy;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const Key('sheet-surface'))).dy, top);
  });
}
