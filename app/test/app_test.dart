import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the app starts and shows its name', (tester) async {
    await tester.pumpWidget(const BacklogManagerApp());

    expect(find.text('Backlog Manager'), findsOneWidget);
  });

  testWidgets('the app uses the Shelf OLED theme by default', (tester) async {
    await tester.pumpWidget(const BacklogManagerApp());

    final context = tester.element(find.text('Backlog Manager'));
    final tokens = Theme.of(context).extension<ShelfTokens>()!;

    expect(tokens.accent, const Color(0xFFF5A524));
    expect(Theme.of(context).scaffoldBackgroundColor, const Color(0xFF000000));
  });
}
