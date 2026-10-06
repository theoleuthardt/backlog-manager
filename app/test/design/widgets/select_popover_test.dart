import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  final tokens = tokensOf('shelfOled');

  group('ShelfSelect', () {
    Widget select({String? value, ValueChanged<String>? onChanged}) {
      return ShelfSelect<String>(
        label: 'Default sort',
        hintText: 'Choose one',
        value: value,
        onChanged: onChanged ?? (_) {},
        options: const [
          ShelfOption(value: 'status', label: 'Status'),
          ShelfOption(value: 'genre', label: 'Genre'),
        ],
      );
    }

    testWidgets('shows the label above a 34 px trigger on surface2', (
      tester,
    ) async {
      await pumpThemed(tester, select(), width: 300);

      expect(
        tester.getTopLeft(find.text('Default sort')).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('select-trigger'))).dy),
      );
      expect(
        tester.getSize(find.byKey(const Key('select-trigger'))).height,
        34,
      );
      final box = tester.widget<DecoratedBox>(
        find.byKey(const Key('select-surface')),
      );
      expect((box.decoration as BoxDecoration).color, tokens.surface2);
    });

    testWidgets('shows the hint in the faint colour while nothing is chosen', (
      tester,
    ) async {
      await pumpThemed(tester, select(), width: 300);

      expect(
        tester.widget<Text>(find.text('Choose one')).style!.color,
        tokens.faint,
      );
    });

    testWidgets('shows the label of the chosen option', (tester) async {
      await pumpThemed(tester, select(value: 'genre'), width: 300);

      expect(find.text('Genre'), findsOneWidget);
      expect(find.text('Choose one'), findsNothing);
    });

    testWidgets(
      'opens the options, marks the chosen one and reports a choice',
      (tester) async {
        String? chosen;
        await pumpThemed(
          tester,
          select(value: 'status', onChanged: (value) => chosen = value),
          width: 300,
        );

        await tester.tap(find.byKey(const Key('select-trigger')));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.check), findsOneWidget);

        await tester.tap(find.text('Genre').last);
        await tester.pumpAndSettle();

        expect(chosen, 'genre');
      },
    );
  });

  group('ShelfPopover', () {
    testWidgets('shows its content from the trigger', (tester) async {
      await pumpThemed(
        tester,
        ShelfPopover(
          content: const SizedBox(
            width: 180,
            height: 60,
            child: Text('Pick a value'),
          ),
          builder: (context, controller) =>
              TextButton(onPressed: controller.open, child: const Text('Open')),
        ),
      );
      expect(find.text('Pick a value'), findsNothing);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Pick a value'), findsOneWidget);
    });
  });
}
