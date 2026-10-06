import 'package:backlog_manager/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the app starts and shows its name', (tester) async {
    await tester.pumpWidget(const BacklogManagerApp());

    expect(find.text('Backlog Manager'), findsOneWidget);
  });
}
