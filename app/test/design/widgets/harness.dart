import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ShelfTokens tokensOf(String id) => ShelfTokens.forTheme(resolveTheme(id, []));

/// Wraps [child] in the app theme of [themeId] on the background colour.
Widget themed(String themeId, Widget child, {double? width}) {
  final tokens = tokensOf(themeId);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildShelfTheme(tokens),
    home: Material(
      color: tokens.background,
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  String themeId = 'shelfOled',
  double? width,
}) async {
  await tester.pumpWidget(themed(themeId, child, width: width));
  await tester.pumpAndSettle();
}

/// Registers one golden test per theme (Shelf OLED and light) for [build].
void goldenInBothThemes(
  String name,
  Widget Function() build, {
  Size size = const Size(520, 240),
  double? width,
}) {
  for (final themeId in ['shelfOled', 'light']) {
    testWidgets('golden: $name in $themeId', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpThemed(tester, build(), themeId: themeId, width: width);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${name}_$themeId.png'),
      );
    });
  }
}
