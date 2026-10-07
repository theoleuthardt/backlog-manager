import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/widgets/banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  final tokens = tokensOf('shelfOled');

  testWidgets('shows an error in the danger colour on a tint of it', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const ShelfBanner(message: 'Invalid email or password'),
      width: 360,
    );

    final box = tester.widget<DecoratedBox>(
      find.byKey(const Key('error-banner')),
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, atOpacity(tokens.danger, 0.12));
    expect(decoration.borderRadius, BorderRadius.circular(8));
    expect(
      tester.widget<Text>(find.text('Invalid email or password')).style!.color,
      tokens.danger,
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('announces itself to assistive technology as a live region', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(
      tester,
      const ShelfBanner(message: 'Account locked'),
      width: 360,
    );

    expect(
      tester.getSemantics(find.byKey(const Key('error-banner'))),
      isSemantics(label: 'Account locked', isLiveRegion: true),
    );
    handle.dispose();
  });

  goldenInBothThemes(
    'banner',
    () => const ShelfBanner(message: 'Your session has ended. Sign in again.'),
    size: const Size(420, 100),
    width: 380,
  );
}
