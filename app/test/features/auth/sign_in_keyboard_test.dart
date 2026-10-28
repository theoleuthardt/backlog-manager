import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../shell/shell_harness.dart';

TextField fieldWithLabel(WidgetTester tester, String label) =>
    tester.widget<TextField>(
      find.descendant(
        of: find
            .ancestor(of: find.text(label), matching: find.byType(Column))
            .first,
        matching: find.byType(TextField),
      ),
    );

void main() {
  testWidgets('the sign-in fields open the right keyboard and autofill', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: const Size(402, 874),
      desktop: false,
      session: const SessionSignedOut(),
    );

    final email = fieldWithLabel(tester, 'Email');
    expect(email.keyboardType, TextInputType.emailAddress);
    expect(email.autofillHints, contains(AutofillHints.email));
    expect(email.textInputAction, TextInputAction.next);

    final password = fieldWithLabel(tester, 'Password');
    expect(password.autofillHints, [AutofillHints.password]);
    expect(find.byType(AutofillGroup), findsOneWidget);
  });
}
