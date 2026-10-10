import 'package:backlog_manager/domain/achievements.dart';
import 'package:flutter_test/flutter_test.dart';

GameAchievement item(
  String name, {
  bool achieved = false,
  String? description,
  bool hidden = false,
}) => GameAchievement(
  apiname: name,
  displayName: name,
  description: description,
  achieved: achieved,
  hidden: hidden,
);

void main() {
  group('GameAchievements.percent', () {
    test('rounds unlocked of total to whole percent', () {
      expect(
        const GameAchievements(unlocked: 3, total: 15, items: []).percent,
        20,
      );
      expect(
        const GameAchievements(unlocked: 1, total: 3, items: []).percent,
        33,
      );
      expect(
        const GameAchievements(unlocked: 2, total: 3, items: []).percent,
        67,
      );
    });

    test('is 0 without achievements', () {
      expect(
        const GameAchievements(unlocked: 0, total: 0, items: []).percent,
        0,
      );
    });
  });

  test('a game without achievements has nothing to show', () {
    expect(
      const GameAchievements(unlocked: 0, total: 0, items: []).isEmpty,
      isTrue,
    );
    expect(
      const GameAchievements(unlocked: 0, total: 5, items: []).isEmpty,
      isFalse,
    );
  });

  group('the line under an achievement', () {
    test('is the description', () {
      expect(item('A', description: 'Win once').detail, 'Win once');
    });

    test('says "Hidden achievement" for a hidden one not yet unlocked', () {
      expect(item('A', hidden: true).detail, 'Hidden achievement');
      expect(
        item('A', hidden: true, description: '').detail,
        'Hidden achievement',
      );
    });

    test('is empty for an unlocked hidden one without description', () {
      expect(item('A', hidden: true, achieved: true).detail, isNull);
    });

    test('is empty for a plain one without description', () {
      expect(item('A').detail, isNull);
    });
  });
}
