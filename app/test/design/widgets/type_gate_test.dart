import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/type_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

Widget fields() => Column(
  children: [
    ElevatedButton(
      key: const Key('before'),
      autofocus: true,
      onPressed: () {},
      child: const Text('Before'),
    ),
    SizedBox(
      width: 200,
      child: TypeGate(
        builder: (context, focusNode) =>
            TextField(key: const Key('gated'), focusNode: focusNode),
      ),
    ),
  ],
);

bool editing(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
      ),
    )
    .focusNode
    .hasFocus;

void main() {
  testWidgets('the D-pad stops on a gated field without typing in it', (
    tester,
  ) async {
    await pumpThemed(tester, fields(), touch: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(editing(tester, 'gated'), isFalse);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TypeGate');
  });

  testWidgets('A starts typing, B stops typing and stays on the field', (
    tester,
  ) async {
    await pumpThemed(tester, fields(), touch: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pumpAndSettle();
    expect(editing(tester, 'gated'), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
    await tester.pumpAndSettle();
    expect(editing(tester, 'gated'), isFalse);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TypeGate');
  });

  testWidgets('the field keeps the size it is given', (tester) async {
    await pumpThemed(
      tester,
      SizedBox(
        width: 200,
        height: 60,
        child: TypeGate(
          builder: (context, focusNode) =>
              TextField(key: const Key('sized'), focusNode: focusNode),
        ),
      ),
      touch: true,
    );

    expect(tester.getSize(find.byKey(const Key('sized'))), const Size(200, 60));
  });

  testWidgets('a tap types at once', (tester) async {
    await pumpThemed(tester, fields(), touch: true);

    await tester.tap(find.byKey(const Key('gated')));
    await tester.pump();

    expect(editing(tester, 'gated'), isTrue);
  });

  testWidgets('the desktop has no gate', (tester) async {
    await pumpThemed(tester, fields());

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(editing(tester, 'gated'), isTrue);
  });

  testWidgets('a gate that takes over a shared field keeps it out of the D-pad '
      'path', (tester) async {
    final shared = FocusNode();
    addTearDown(shared.dispose);
    Widget page(String key) => SizedBox(
      key: ValueKey(key),
      width: 200,
      child: TypeGate(
        focusNode: shared,
        builder: (context, focusNode) => TextField(focusNode: focusNode),
      ),
    );

    var keys = ['library'];
    late StateSetter setKeys;
    await pumpThemed(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          setKeys = setState;
          return Column(
            children: [
              ElevatedButton(
                autofocus: true,
                onPressed: () {},
                child: const Text('Before'),
              ),
              for (final key in keys) page(key),
            ],
          );
        },
      ),
      touch: true,
    );

    setKeys(() => keys = ['library', 'space']);
    await tester.pump();
    setKeys(() => keys = ['space']);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(shared.hasFocus, isFalse);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TypeGate');
  });

  testWidgets('the D-pad stops on a ShelfField without typing in it', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      Column(
        children: [
          ElevatedButton(
            autofocus: true,
            onPressed: () {},
            child: const Text('Before'),
          ),
          const SizedBox(
            width: 200,
            child: ShelfField(key: Key('field'), label: 'Name'),
          ),
        ],
      ),
      touch: true,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(editing(tester, 'field'), isFalse);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TypeGate');
  });

  testWidgets('the next key of the keyboard types in the next ShelfField', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const Column(
        children: [
          SizedBox(
            width: 200,
            child: ShelfField(
              key: Key('email'),
              label: 'Email',
              textInputAction: TextInputAction.next,
            ),
          ),
          SizedBox(
            width: 200,
            child: ShelfField(key: Key('password'), label: 'Password'),
          ),
        ],
      ),
      touch: true,
    );

    await tester.tap(find.byKey(const Key('email')));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(editing(tester, 'password'), isTrue);
  });
}
