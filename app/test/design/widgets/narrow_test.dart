import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

const _phone = Size(402, 874);

void _onScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _row() => const ShelfFormRow(
  label: 'Default sort',
  description: 'How the library is sorted when it opens',
  control: SizedBox(key: Key('control'), width: 220, height: 32),
);

Widget _footer() => ShelfSheetFooter(
  onCancel: () {},
  primary: ShelfButton(
    label: 'Save as CSV...',
    kind: ShelfButtonKind.primary,
    onPressed: () {},
  ),
);

void main() {
  group('ShelfFormRow', () {
    testWidgets('keeps the control beside the label when there is room', (
      tester,
    ) async {
      _onScreen(tester, const Size(1000, 400));
      await pumpThemed(tester, _row(), width: 640);

      final label = tester.getTopLeft(find.text('Default sort'));
      final control = tester.getTopLeft(find.byKey(const Key('control')));
      expect(control.dx, greaterThan(label.dx + 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('puts the control below the label on a phone', (tester) async {
      _onScreen(tester, _phone);
      await pumpThemed(tester, _row(), width: 360, compact: true);

      final label = tester.getTopLeft(find.text('Default sort'));
      final description = tester.getBottomLeft(
        find.text('How the library is sorted when it opens'),
      );
      final control = tester.getTopLeft(find.byKey(const Key('control')));
      expect(control.dx, label.dx);
      expect(control.dy, greaterThan(description.dy));
      expect(tester.takeException(), isNull);
    });
  });

  group('ShelfSheetFooter', () {
    testWidgets('shows the Esc hint when there is room', (tester) async {
      _onScreen(tester, const Size(1000, 400));
      await pumpThemed(tester, _footer(), width: 600);

      expect(find.text('Esc'), findsOneWidget);
    });

    testWidgets('leaves the keyboard hint out on any phone', (tester) async {
      _onScreen(tester, const Size(440, 900));
      await pumpThemed(tester, _footer(), width: 400, compact: true);

      expect(find.text('Esc'), findsNothing);
    });

    testWidgets('fits a phone without the keyboard hint', (tester) async {
      _onScreen(tester, _phone);
      await pumpThemed(tester, _footer(), width: 300);

      expect(find.text('Esc'), findsNothing);
      expect(find.text('Save as CSV...'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ShelfSheet', () {
    testWidgets('is never wider than the room it is given', (tester) async {
      _onScreen(tester, _phone);
      await pumpThemed(
        tester,
        const ShelfSheet(
          title: 'Export Backlog',
          width: ShelfSheetWidth.compact,
          child: SizedBox(height: 40),
        ),
      );

      expect(
        tester.getSize(find.byKey(const Key('sheet-surface'))).width,
        lessThanOrEqualTo(_phone.width - 40),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens from the bottom over the full width on a phone', (
      tester,
    ) async {
      _onScreen(tester, _phone);
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showShelfSheet<void>(
              context,
              builder: (_) => const ShelfSheet(
                title: 'Add Game',
                width: ShelfSheetWidth.wide,
                child: SizedBox(height: 120),
              ),
            ),
            child: const Text('open'),
          ),
        ),
        compact: true,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final sheet = tester.getRect(find.byKey(const Key('sheet-surface')));
      expect(sheet.width, _phone.width);
      expect(sheet.bottom, _phone.height);
      expect(tester.takeException(), isNull);
    });

    testWidgets('drops from the top in its own width on the desktop', (
      tester,
    ) async {
      _onScreen(tester, const Size(1440, 900));
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showShelfSheet<void>(
              context,
              builder: (_) => const ShelfSheet(
                title: 'Add Game',
                width: ShelfSheetWidth.wide,
                child: SizedBox(height: 120),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final sheet = tester.getRect(find.byKey(const Key('sheet-surface')));
      expect(sheet.width, ShelfSheetWidth.wide.value);
      expect(sheet.top, 60);
    });
  });
}
