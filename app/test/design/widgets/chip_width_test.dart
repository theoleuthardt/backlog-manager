import 'package:backlog_manager/design/widgets/chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_font.dart';
import 'harness.dart';

void main() {
  setUpAll(loadAppFont);

  testWidgets(
    'a chip in a narrow space shortens its label instead of overflowing',
    (tester) async {
      await tester.pumpWidget(
        themed(
          'shelfOled',
          const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: 60, child: ShelfChip(label: 'In Progress')),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ShelfChip)).width,
        lessThanOrEqualTo(60),
      );
    },
  );

  testWidgets('a chip with room keeps its whole label', (tester) async {
    await tester.pumpWidget(
      themed('shelfOled', const ShelfChip(label: 'In Progress')),
    );

    final text = tester.widget<Text>(find.text('In Progress'));
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.getSize(find.byType(ShelfChip)).width, greaterThan(60));
  });
}
