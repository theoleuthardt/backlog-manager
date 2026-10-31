import 'package:backlog_manager/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import 'library_page_test.dart' show pumpLibrary;

const _games = [
  BacklogEntry(id: 1, title: 'Alpha', status: 'In Progress', interest: 3),
  BacklogEntry(id: 2, title: 'Bravo', status: 'In Progress', interest: 9),
  BacklogEntry(id: 3, title: 'Charlie', status: 'In Progress', interest: 6),
];

List<String> shownOrder(WidgetTester tester) {
  final positions = {
    for (final game in _games)
      game.title: tester.getTopLeft(find.text(game.title).first),
  };
  final titles = positions.keys.toList()
    ..sort((a, b) {
      final pa = positions[a]!;
      final pb = positions[b]!;
      return pa.dy == pb.dy ? pa.dx.compareTo(pb.dx) : pa.dy.compareTo(pb.dy);
    });
  return titles;
}

void main() {
  testWidgets('a group orders its games by title until told otherwise', (
    tester,
  ) async {
    await pumpLibrary(tester, FakeBacklogApi(entries: _games));

    expect(shownOrder(tester), ['Alpha', 'Bravo', 'Charlie']);
  });

  testWidgets('the sort menu of a group header orders only that group', (
    tester,
  ) async {
    await pumpLibrary(tester, FakeBacklogApi(entries: _games));

    await tester.tap(
      find.byKey(const Key('group-entry-order-status:In Progress')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interest').last);
    await tester.pumpAndSettle();

    expect(shownOrder(tester), ['Bravo', 'Charlie', 'Alpha']);
  });
}
