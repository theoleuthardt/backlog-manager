import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/stepper.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

Widget sheetBody({double? width}) {
  return ShelfSheet(
    title: 'Add a game',
    description: 'Search IGDB for the game',
    footer: ShelfSheetFooter(
      onCancel: () {},
      primary: ShelfButton(
        label: 'Continue',
        kind: ShelfButtonKind.primary,
        onPressed: () {},
      ),
    ),
    child: const Text('Results'),
  );
}

void main() {
  final tokens = tokensOf('shelfOled');

  group('ShelfSheet', () {
    testWidgets('has a head, a body and a footer', (tester) async {
      await pumpThemed(tester, sheetBody());

      expect(find.text('Add a game'), findsOneWidget);
      expect(find.text('Search IGDB for the game'), findsOneWidget);
      expect(find.text('Results'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      final head = tester.getTopLeft(find.text('Add a game')).dy;
      final body = tester.getTopLeft(find.text('Results')).dy;
      final foot = tester.getTopLeft(find.text('Continue')).dy;
      expect(head, lessThan(body));
      expect(body, lessThan(foot));
    });

    testWidgets('is 640 wide by default and has the compact and wide widths', (
      tester,
    ) async {
      await pumpThemed(tester, sheetBody());
      expect(tester.getSize(find.byKey(const Key('sheet-surface'))).width, 640);

      await pumpThemed(
        tester,
        ShelfSheet(
          title: 'Export',
          width: ShelfSheetWidth.compact,
          child: const Text('Body'),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('sheet-surface'))).width, 520);

      await pumpThemed(
        tester,
        ShelfSheet(
          title: 'Find',
          width: ShelfSheetWidth.wide,
          child: const Text('Body'),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('sheet-surface'))).width, 680);
    });

    testWidgets('is a surface with the dialog radius and the strong border', (
      tester,
    ) async {
      await pumpThemed(tester, sheetBody());

      final box = tester.widget<DecoratedBox>(
        find.byKey(const Key('sheet-surface')),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, tokens.surface);
      expect(decoration.borderRadius, BorderRadius.circular(16));
      expect((decoration.border! as Border).top.color, tokens.borderStrong);
    });

    testWidgets(
      'puts the footer on surface2 with Cancel and its Esc hint on the left',
      (tester) async {
        await pumpThemed(tester, sheetBody());

        final footer = tester.widget<ColoredBox>(
          find.byKey(const Key('sheet-footer')),
        );
        expect(footer.color, tokens.surface2);
        expect(find.text('Esc'), findsOneWidget);
        expect(
          tester.getCenter(find.text('Cancel')).dx,
          lessThan(tester.getCenter(find.text('Continue')).dx),
        );
      },
    );

    testWidgets('reports Cancel and the close button', (tester) async {
      var cancelled = 0;
      var closed = 0;
      await pumpThemed(
        tester,
        ShelfSheet(
          title: 'Export',
          onClose: () => closed++,
          footer: ShelfSheetFooter(
            onCancel: () => cancelled++,
            primary: const ShelfButton(label: 'Export', onPressed: null),
          ),
          child: const Text('Body'),
        ),
      );

      await tester.tap(find.text('Cancel'));
      await tester.tap(find.byTooltip('Close'));

      expect(cancelled, 1);
      expect(closed, 1);
    });
  });

  group('showShelfSheet', () {
    Widget opener({bool dismissible = true}) {
      return Builder(
        builder: (context) => TextButton(
          onPressed: () => showShelfSheet<void>(
            context,
            dismissible: dismissible,
            builder: (context) =>
                ShelfSheet(title: 'Add a game', child: const Text('Results')),
          ),
          child: const Text('Open'),
        ),
      );
    }

    testWidgets(
      'drops the sheet from below the title bar over a dimmed window',
      (tester) async {
        await pumpThemed(tester, opener());

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Results'), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(const Key('sheet-surface'))).dy,
          greaterThanOrEqualTo(52),
        );
        final barrier = tester.widget<ModalBarrier>(
          find.byType(ModalBarrier).last,
        );
        expect(barrier.color, isNotNull);
      },
    );

    testWidgets('closes with Esc and with a click on the barrier', (
      tester,
    ) async {
      await pumpThemed(tester, opener());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Results'), findsNothing);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 590));
      await tester.pumpAndSettle();
      expect(find.text('Results'), findsNothing);
    });

    testWidgets('cannot be closed while it is not dismissible', (tester) async {
      await pumpThemed(tester, opener(dismissible: false));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tapAt(const Offset(5, 590));
      await tester.pumpAndSettle();

      expect(find.text('Results'), findsOneWidget);
    });
  });

  group('ShelfToast', () {
    testWidgets('is a surface2 card with the message and an action', (
      tester,
    ) async {
      var undone = 0;
      await pumpThemed(
        tester,
        ShelfToast(
          message: 'Moved to Completed',
          actionLabel: 'Undo',
          onAction: () => undone++,
        ),
      );

      final box = tester.widget<DecoratedBox>(
        find.byKey(const Key('toast-surface')),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, tokens.surface2);
      expect(decoration.borderRadius, BorderRadius.circular(10));
      expect(find.text('Moved to Completed'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      expect(undone, 1);
      expect(
        tester.widget<Text>(find.text('Undo')).style!.color,
        tokens.accent,
      );
    });

    testWidgets('has no action button without an action', (tester) async {
      await pumpThemed(tester, const ShelfToast(message: 'Saved'));

      expect(find.byType(ShelfButton), findsNothing);
    });
  });

  group('showShelfToast', () {
    Widget opener(void Function(BuildContext) show) {
      return Builder(
        builder: (context) => TextButton(
          onPressed: () => show(context),
          child: const Text('Open'),
        ),
      );
    }

    testWidgets(
      'shows the toast above the status bar and removes it after its duration',
      (tester) async {
        await pumpThemed(
          tester,
          opener(
            (context) => showShelfToast(
              context,
              'Saved',
              duration: const Duration(seconds: 3),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pump();
        expect(find.text('Saved'), findsOneWidget);
        expect(
          tester.getBottomLeft(find.byKey(const Key('toast-surface'))).dy,
          lessThan(600 - 28),
        );

        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.text('Saved'), findsNothing);
      },
    );

    testWidgets('replaces the toast that is still showing', (tester) async {
      await pumpThemed(
        tester,
        opener((context) {
          showShelfToast(context, 'First');
          showShelfToast(context, 'Second');
        }),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
    });

    testWidgets('runs the action and removes the toast', (tester) async {
      var undone = 0;
      await pumpThemed(
        tester,
        opener(
          (context) => showShelfToast(
            context,
            'Moved',
            actionLabel: 'Undo',
            onAction: () => undone++,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(undone, 1);
      expect(find.text('Moved'), findsNothing);
    });
  });

  group('ShelfStepper', () {
    testWidgets(
      'marks done steps with a check, the current step in the accent',
      (tester) async {
        await pumpThemed(
          tester,
          const ShelfStepper(
            steps: ['Theme', 'Sort', 'Steam', 'Done'],
            current: 2,
          ),
          width: 240,
        );

        BoxDecoration circle(int index) =>
            tester
                    .widget<DecoratedBox>(find.byKey(Key('step-$index-circle')))
                    .decoration
                as BoxDecoration;

        expect(circle(0).color, tokens.success);
        expect(circle(1).color, tokens.success);
        expect(find.byIcon(Icons.check), findsNWidgets(2));
        expect(circle(2).color, tokens.accent);
        expect(circle(3).color, isNull);
        expect((circle(3).border! as Border).top.color, tokens.faint);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);
      },
    );

    testWidgets('is 36 px per step with the labels beside the circles', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const ShelfStepper(steps: ['Theme', 'Sort'], current: 0),
        width: 240,
      );

      expect(tester.getSize(find.byKey(const Key('step-0'))).height, 36);
      expect(
        tester.getCenter(find.byKey(const Key('step-0-circle'))).dx,
        lessThan(tester.getCenter(find.text('Theme')).dx),
      );
      expect(
        tester.widget<Text>(find.text('Theme')).style!.color,
        tokens.foreground,
      );
      expect(tester.widget<Text>(find.text('Sort')).style!.color, tokens.faint);
    });
  });

  goldenInBothThemes(
    'sheet_toast_stepper',
    () => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 150,
          child: ShelfStepper(
            steps: ['Theme', 'Sort', 'Steam', 'Done'],
            current: 2,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              ShelfSheet(
                title: 'Add a game',
                description: 'Search IGDB for the game',
                width: ShelfSheetWidth.compact,
                footer: ShelfSheetFooter(
                  onCancel: () {},
                  primary: ShelfButton(
                    label: 'Continue',
                    kind: ShelfButtonKind.primary,
                    onPressed: () {},
                  ),
                ),
                child: const Text('Results'),
              ),
              const SizedBox(height: 16),
              ShelfToast(
                message: 'Moved to Completed',
                actionLabel: 'Undo',
                onAction: () {},
              ),
            ],
          ),
        ),
      ],
    ),
    size: const Size(780, 420),
    width: 740,
  );
}
