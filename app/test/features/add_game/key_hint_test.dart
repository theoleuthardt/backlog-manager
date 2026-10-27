import 'package:backlog_manager/features/add_game/game_result_parts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design/widgets/harness.dart';

void main() {
  Future<void> pumpOn(WidgetTester tester, {required bool compact}) =>
      pumpThemed(tester, const KeyHint('Enter'), compact: compact);

  testWidgets('shows the key on the desktop', (tester) async {
    await pumpOn(tester, compact: false);
    expect(find.text('Enter'), findsOneWidget);
  });

  testWidgets('is left out on a phone, which has no keyboard', (tester) async {
    await pumpOn(tester, compact: true);
    expect(find.text('Enter'), findsNothing);
  });
}
