import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/design/widgets/spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  group('ShelfSpinner', () {
    testWidgets('has the size it was given and a label for screen readers', (
      tester,
    ) async {
      await pumpThemed(tester, const ShelfSpinner(size: 40));

      expect(
        tester.getSize(find.byKey(const Key('shelf-spinner'))),
        const Size.square(40),
      );
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });

    testWidgets('stands still while the motion is off, so a page can settle', (
      tester,
    ) async {
      await pumpThemed(tester, const ShelfSpinner());

      expect(tester.hasRunningAnimations, isFalse);
    });

    group('with the motion on', () {
      late bool saved;

      setUp(() {
        saved = atmosphereMotion;
        atmosphereMotion = true;
      });
      tearDown(() => atmosphereMotion = saved);

      testWidgets('runs, and stops when the system asks for less motion', (
        tester,
      ) async {
        await tester.pumpWidget(themed('shelfOled', const ShelfSpinner()));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.hasRunningAnimations, isTrue);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: themed('shelfOled', const ShelfSpinner()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.hasRunningAnimations, isFalse);
      });
    });

    goldenInBothThemes(
      'spinner',
      () => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShelfSpinner(size: 16),
          SizedBox(width: 16),
          ShelfSpinner(),
          SizedBox(width: 16),
          ShelfSpinner(size: 64),
        ],
      ),
      size: const Size(240, 140),
    );
  });
}
