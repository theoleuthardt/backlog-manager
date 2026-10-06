import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the app opens at sign-in', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BacklogManagerApp()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('page-sign-in')), findsOneWidget);
  });

  testWidgets('the app uses the Shelf OLED theme by default', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BacklogManagerApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byKey(const Key('page-sign-in')));
    final tokens = Theme.of(context).extension<ShelfTokens>()!;

    expect(tokens.accent, const Color(0xFFF5A524));
    expect(Theme.of(context).scaffoldBackgroundColor, const Color(0xFF000000));
  });
}
