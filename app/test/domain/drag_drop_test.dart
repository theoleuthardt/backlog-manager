import 'package:backlog_manager/domain/drag_drop.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

const rpg = Category(id: 1, name: 'RPG', color: '#ff0000');
const indie = Category(id: 2, name: 'Indie', color: '#00ff00');
const co = Category(id: 3, name: 'Co-op', color: '#0000ff');

void main() {
  group('groupIndexAt', () {
    final tops = {0: 100.0, 1: 400.0, 2: 700.0};

    test('is the last group whose header is above the pointer', () {
      expect(groupIndexAt(120, tops), 0);
      expect(groupIndexAt(399, tops), 0);
      expect(groupIndexAt(400, tops), 1);
      expect(groupIndexAt(900, tops), 2);
    });

    test('is the group before the first visible header above all of them', () {
      expect(groupIndexAt(40, {3: 100.0, 4: 300.0}), 2);
    });

    test('is nothing above the very first group or without headers', () {
      expect(groupIndexAt(40, tops), isNull);
      expect(groupIndexAt(40, {}), isNull);
    });
  });

  group('categoryMove', () {
    test('adds the target and removes the first category', () {
      final move = categoryMove(assigned: [rpg], target: indie)!;
      expect(move.add, indie);
      expect(move.remove, rpg);
    });

    test('only adds when the game had no category yet', () {
      final move = categoryMove(assigned: const [], target: indie)!;
      expect(move.add, indie);
      expect(move.remove, isNull);
    });

    test('does nothing when the target is the first category', () {
      expect(categoryMove(assigned: [rpg, indie], target: rpg), isNull);
    });

    test('keeps a target the game already has and drops the first one', () {
      final move = categoryMove(assigned: [rpg, indie], target: indie)!;
      expect(move.add, isNull);
      expect(move.remove, rpg);
    });

    test('leaves the other categories alone', () {
      final move = categoryMove(assigned: [rpg, indie], target: co)!;
      expect(move.add, co);
      expect(move.remove, rpg);
    });
  });

  group('edgeScrollVelocity', () {
    test('is zero away from the edges', () {
      expect(edgeScrollVelocity(300, top: 0, bottom: 600), 0);
    });

    test('scrolls up near the top and down near the bottom', () {
      expect(edgeScrollVelocity(10, top: 0, bottom: 600), lessThan(0));
      expect(edgeScrollVelocity(590, top: 0, bottom: 600), greaterThan(0));
    });

    test('is faster the closer the pointer is to the edge', () {
      final near = edgeScrollVelocity(5, top: 0, bottom: 600).abs();
      final far = edgeScrollVelocity(50, top: 0, bottom: 600).abs();
      expect(near, greaterThan(far));
    });

    test('is capped when the pointer leaves the viewport', () {
      final capped = edgeScrollVelocity(-500, top: 0, bottom: 600);
      expect(capped, edgeScrollVelocity(0, top: 0, bottom: 600));
    });
  });
}
