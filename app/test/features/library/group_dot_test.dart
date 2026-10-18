import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import 'library_page_test.dart' show backlog, pumpLibrary;

const rpg = Category(id: 1, name: 'RPG', color: '#ff0000');
const indie = Category(id: 2, name: 'Indie', color: '#00ff00');
const cozy = Category(id: 3, name: 'Cozy', color: '#0000ff');

Color dotOf(WidgetTester tester, String groupKey) {
  final dot = find.descendant(
    of: find.byKey(Key('group-handle-$groupKey')),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle,
    ),
  );
  return (tester.widget<DecoratedBox>(dot).decoration as BoxDecoration).color!;
}

FakeBacklogApi categorized() => FakeBacklogApi(entries: backlog)
  ..categoryList = [rpg, indie, cozy]
  ..entriesByCategory = {
    1: [backlog[0]],
    2: [backlog[1]],
  };

void main() {
  testWidgets('the dot of a category group has the colour of the category', (
    tester,
  ) async {
    await pumpLibrary(tester, categorized(), defaultSort: 'category');

    expect(dotOf(tester, 'category:RPG'), const Color(0xffff0000));
    expect(dotOf(tester, 'category:Indie'), const Color(0xff00ff00));
    expect(dotOf(tester, 'category:Cozy'), const Color(0xff0000ff));
  });

  testWidgets('games without a category and other sorts keep the accent', (
    tester,
  ) async {
    await pumpLibrary(tester, categorized(), defaultSort: 'category');
    final tokens = Theme.of(
      tester.element(find.byKey(const Key('group-category:RPG'))),
    ).extension<ShelfTokens>()!;

    expect(dotOf(tester, 'category:Uncategorized'), tokens.accent);
  });
}
