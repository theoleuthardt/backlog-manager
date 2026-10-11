import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget sky({bool reduceMotion = false}) {
  final tokens = ShelfTokens.forTheme(resolveTheme('shelfOled', []));
  return ProviderScope(
    child: MaterialApp(
      theme: buildShelfTheme(tokens),
      builder: (context, home) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: home!,
      ),
      home: const SizedBox(
        width: 1200,
        height: 800,
        child: AtmosphereBackground(child: SizedBox.expand()),
      ),
    ),
  );
}

Iterable<CustomPainter> painters(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<CustomPainter>();

void main() {
  setUp(() => atmosphereMotion = true);
  tearDown(() => atmosphereMotion = false);

  testWidgets('the sky twinkles and keeps animating', (tester) async {
    await tester.pumpWidget(sky());

    expect(
      painters(tester).whereType<AtmosphereTwinklePainter>(),
      hasLength(1),
    );
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('the bright stars belong to the moving layer only', (
    tester,
  ) async {
    await tester.pumpWidget(sky());

    final still = painters(tester).whereType<AtmospherePainter>().single;
    expect(still.brightStars, isFalse);
  });

  testWidgets('the sky stands still when the system asks for less motion', (
    tester,
  ) async {
    await tester.pumpWidget(sky(reduceMotion: true));

    expect(painters(tester).whereType<AtmosphereTwinklePainter>(), isEmpty);
    expect(
      painters(tester).whereType<AtmospherePainter>().single.brightStars,
      isTrue,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('and in tests, where it is switched off', (tester) async {
    atmosphereMotion = false;
    await tester.pumpWidget(sky());

    expect(painters(tester).whereType<AtmosphereTwinklePainter>(), isEmpty);
  });
}
