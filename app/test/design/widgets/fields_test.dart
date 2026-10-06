import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  final tokens = tokensOf('shelfOled');

  group('ShelfField', () {
    testWidgets('puts the label above a 34 px input on surface2', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const ShelfField(label: 'Title', hintText: 'Name of the game'),
        width: 300,
      );

      final label = tester.getTopLeft(find.text('Title'));
      final input = tester.getTopLeft(find.byType(TextField));
      expect(label.dy, lessThan(input.dy));
      expect(tester.getSize(find.byType(TextField)).height, 34);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintText, 'Name of the game');
      final theme = Theme.of(tester.element(find.byType(TextField)));
      expect(theme.inputDecorationTheme.fillColor, tokens.surface2);
      expect(theme.inputDecorationTheme.filled, isTrue);
    });

    testWidgets('writes the label in muted 12 px text', (tester) async {
      await pumpThemed(tester, const ShelfField(label: 'Title'), width: 300);

      final style = tester.widget<Text>(find.text('Title')).style!;
      expect(style.fontSize, 12);
      expect(style.color, tokens.muted);
    });

    testWidgets('shows a hint below the input in the faint colour', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const ShelfField(label: 'Title', hint: 'Shown on the cover'),
        width: 300,
      );

      expect(
        tester.getTopLeft(find.text('Shown on the cover')).dy,
        greaterThan(tester.getBottomLeft(find.byType(TextField)).dy),
      );
      expect(
        tester.widget<Text>(find.text('Shown on the cover')).style!.color,
        tokens.faint,
      );
    });

    testWidgets('shows an error instead of the hint in the danger colour', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const ShelfField(label: 'Title', hint: 'Hint', error: 'Required'),
        width: 300,
      );

      expect(find.text('Hint'), findsNothing);
      expect(
        tester.widget<Text>(find.text('Required')).style!.color,
        tokens.danger,
      );
    });

    testWidgets('reports what is typed', (tester) async {
      String? typed;
      await pumpThemed(
        tester,
        ShelfField(label: 'Title', onChanged: (value) => typed = value),
        width: 300,
      );

      await tester.enterText(find.byType(TextField), 'Hades');

      expect(typed, 'Hades');
    });

    testWidgets('can hide a password', (tester) async {
      await pumpThemed(
        tester,
        const ShelfField(label: 'Password', obscure: true),
        width: 300,
      );

      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
    });
  });

  group('ShelfFormGroup', () {
    Widget group() {
      return const ShelfFormGroup(
        title: 'General',
        description: 'How the app sorts your games',
        rows: [
          ShelfFormRow(
            label: 'Default sort',
            description: 'Used when you open the library',
            control: Text('Status'),
          ),
          ShelfFormRow(label: 'Owned only', control: Text('Off')),
          ShelfFormRow(label: 'Language', control: Text('English')),
        ],
      );
    }

    testWidgets('is a surface with the panel radius', (tester) async {
      await pumpThemed(tester, group(), width: 520);

      final box = tester.widget<DecoratedBox>(
        find.byKey(const Key('form-group-surface')),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, tokens.surface);
      expect(decoration.borderRadius, BorderRadius.circular(14));
    });

    testWidgets('has the title and the description above the rows', (
      tester,
    ) async {
      await pumpThemed(tester, group(), width: 520);

      expect(
        tester.widget<Text>(find.text('General')).style!.fontWeight,
        FontWeight.w800,
      );
      expect(
        tester.getTopLeft(find.text('General')).dy,
        lessThan(tester.getTopLeft(find.text('Default sort')).dy),
      );
      expect(find.text('How the app sorts your games'), findsOneWidget);
    });

    testWidgets('separates the rows with 1 px dividers', (tester) async {
      await pumpThemed(tester, group(), width: 520);

      expect(find.byKey(const Key('form-row-divider')), findsNWidgets(2));
      expect(
        tester.getSize(find.byKey(const Key('form-row-divider')).first).height,
        1,
      );
    });

    testWidgets('puts the label on the left and the control on the right', (
      tester,
    ) async {
      await pumpThemed(tester, group(), width: 520);

      expect(
        tester.getCenter(find.text('Default sort')).dx,
        lessThan(tester.getCenter(find.text('Status')).dx),
      );
      expect(find.text('Used when you open the library'), findsOneWidget);
    });
  });

  goldenInBothThemes(
    'fields',
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShelfField(
          label: 'Title',
          hintText: 'Name of the game',
          hint: 'Shown on the cover',
        ),
        const SizedBox(height: 14),
        const ShelfField(label: 'Email', error: 'Enter a valid address'),
        const SizedBox(height: 18),
        const ShelfFormGroup(
          title: 'General',
          description: 'How the app sorts your games',
          rows: [
            ShelfFormRow(
              label: 'Default sort',
              description: 'Used when you open the library',
              control: Text('Status'),
            ),
            ShelfFormRow(label: 'Language', control: Text('English')),
          ],
        ),
      ],
    ),
    size: const Size(540, 420),
    width: 500,
  );
}
