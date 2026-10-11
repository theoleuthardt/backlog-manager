import 'package:backlog_manager/domain/group_order.dart';
import 'package:backlog_manager/domain/library_groups.dart';
import 'package:flutter_test/flutter_test.dart';

LibraryGroup libraryGroup(String key) =>
    LibraryGroup(key: key, label: key, entries: const []);

List<String> keys(List<LibraryGroup> groups) => [
  for (final group in groups) group.key,
];

void main() {
  group('applyGroupOrder', () {
    final groups = [
      libraryGroup('a'),
      libraryGroup('b'),
      libraryGroup('c'),
      libraryGroup('d'),
    ];

    test('keeps the default order without a saved order', () {
      expect(keys(applyGroupOrder(groups, const [])), ['a', 'b', 'c', 'd']);
    });

    test('puts the groups in the saved order', () {
      expect(keys(applyGroupOrder(groups, ['c', 'a', 'b', 'd'])), [
        'c',
        'a',
        'b',
        'd',
      ]);
    });

    test('ignores saved keys that no group has any more', () {
      expect(keys(applyGroupOrder(groups, ['x', 'd', 'a'])), [
        'd',
        'a',
        'b',
        'c',
      ]);
    });

    test('puts groups the saved order does not know after the known ones', () {
      expect(keys(applyGroupOrder(groups, ['c', 'b'])), ['c', 'b', 'a', 'd']);
    });
  });

  group('moveGroup', () {
    const order = ['a', 'b', 'c', 'd'];

    test('moves a group down onto a later one', () {
      expect(moveGroup(order, from: 'a', onto: 'c'), ['b', 'c', 'a', 'd']);
    });

    test('moves a group up onto an earlier one', () {
      expect(moveGroup(order, from: 'd', onto: 'b'), ['a', 'd', 'b', 'c']);
    });

    test('moves a group to the end onto the last one', () {
      expect(moveGroup(order, from: 'a', onto: 'd'), ['b', 'c', 'd', 'a']);
    });

    test('changes nothing for the same group or an unknown one', () {
      expect(moveGroup(order, from: 'b', onto: 'b'), order);
      expect(moveGroup(order, from: 'x', onto: 'b'), order);
      expect(moveGroup(order, from: 'b', onto: 'x'), order);
    });
  });

  group('step', () {
    const order = ['a', 'b', 'c'];

    test('moves a group one place', () {
      expect(moveGroupBy(order, 'b', -1), ['b', 'a', 'c']);
      expect(moveGroupBy(order, 'b', 1), ['a', 'c', 'b']);
    });

    test('stops at both ends', () {
      expect(moveGroupBy(order, 'a', -1), order);
      expect(moveGroupBy(order, 'c', 1), order);
    });
  });

  group('encoding', () {
    test('round-trips the order', () {
      expect(decodeGroupOrder(encodeGroupOrder(['a', 'b:c'])), ['a', 'b:c']);
    });

    test('reads nothing usable as an empty order', () {
      expect(decodeGroupOrder(null), isEmpty);
      expect(decodeGroupOrder('nope'), isEmpty);
      expect(decodeGroupOrder('{"a":1}'), isEmpty);
      expect(decodeGroupOrder('[1,"a"]'), ['a']);
    });
  });
}
