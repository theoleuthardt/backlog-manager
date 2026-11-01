import 'package:backlog_manager/design/widgets/note.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('a closable note goes away with its button', (tester) async {
    await pumpThemed(tester, const ShelfNote(text: 'A hint', closable: true));
    expect(find.text('A hint'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('A hint'), findsNothing);
  });

  testWidgets('a note has no button by default', (tester) async {
    await pumpThemed(tester, const ShelfNote(text: 'A hint'));

    expect(find.byTooltip('Close'), findsNothing);
  });
}
