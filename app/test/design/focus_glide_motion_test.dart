import 'dart:ui';

import 'package:backlog_manager/design/focus_glide_motion.dart';
import 'package:flutter_test/flutter_test.dart';

const _frame = 1 / 60;

/// Steps [motion] for [seconds] in frames of 60 Hz.
void run(GlideMotion motion, double seconds) {
  for (var t = 0.0; t < seconds; t += _frame) {
    motion.step(_frame);
  }
}

void settle(GlideMotion motion) {
  for (var i = 0; i < 600 && motion.animating; i++) {
    motion.step(_frame);
  }
  expect(motion.animating, isFalse, reason: 'settles within ten seconds');
}

const a = Rect.fromLTWH(20, 20, 100, 60);
const b = Rect.fromLTWH(140, 20, 100, 60);

void main() {
  test('shows at the first target from a little larger and fades in', () {
    final motion = GlideMotion()..show(a, radius: 8);

    expect(motion.rect.left, lessThan(a.left));
    expect(motion.rect.right, greaterThan(a.right));
    expect(motion.opacity, 0);

    settle(motion);
    expect(motion.rect, rectMoreOrLessEquals(a, epsilon: 0.5));
    expect(motion.opacity, 1);
    expect(motion.corner, closeTo(8, 0.5));
  });

  test('the edge in the direction of the move leads and the other trails', () {
    final motion = GlideMotion()..show(a, radius: 8);
    settle(motion);

    motion.moveTo(b, radius: 8, elapsedSinceLastMove: 1);
    run(motion, 0.05);

    final rightMoved = motion.rect.right - a.right;
    final leftMoved = motion.rect.left - a.left;
    expect(rightMoved, greaterThan(leftMoved * 1.5));
    expect(motion.rect.width, greaterThan(a.width), reason: 'it stretches');

    settle(motion);
    expect(motion.rect, rectMoreOrLessEquals(b, epsilon: 0.5));
  });

  test('the leading edge overshoots a little and comes back', () {
    final motion = GlideMotion()..show(a, radius: 8);
    settle(motion);

    motion.moveTo(b, radius: 8, elapsedSinceLastMove: 1);
    var furthest = 0.0;
    for (var i = 0; i < 60; i++) {
      motion.step(_frame);
      if (motion.rect.right > furthest) furthest = motion.rect.right;
    }

    expect(furthest, greaterThan(b.right));
    expect(furthest, lessThan(b.right + 20));
  });

  test('a held D-pad moves all edges together with firmer springs', () {
    final motion = GlideMotion()..show(a, radius: 8);
    settle(motion);

    motion.moveTo(b, radius: 8, elapsedSinceLastMove: 0.1);
    run(motion, 0.05);

    final rightMoved = motion.rect.right - a.right;
    final leftMoved = motion.rect.left - a.left;
    expect(leftMoved, closeTo(rightMoved, 1));
  });

  test('a far jump shrinks to a dot that flies there and opens', () {
    final motion = GlideMotion()..show(a, radius: 8);
    settle(motion);
    const far = Rect.fromLTWH(20, 600, 100, 60);

    motion.moveTo(far, radius: 8, elapsedSinceLastMove: 1);
    run(motion, 0.1);
    expect(motion.rect.width, lessThan(20), reason: 'a dot');
    expect(motion.solid, greaterThan(0.5));

    run(motion, 0.15);
    expect(motion.rect.center.dy, greaterThan(a.center.dy + 50));
    expect(motion.rect.center.dy, lessThan(far.center.dy));

    settle(motion);
    expect(motion.rect, rectMoreOrLessEquals(far, epsilon: 0.5));
    expect(motion.solid, 0);
  });

  test('a held D-pad never turns a far move into a dot', () {
    final motion = GlideMotion()..show(a, radius: 8);
    settle(motion);
    const far = Rect.fromLTWH(20, 600, 100, 60);

    motion.moveTo(far, radius: 8, elapsedSinceLastMove: 0.1);
    run(motion, 0.1);

    expect(motion.rect.width, greaterThan(90));
  });

  test('follows a target that scrolls', () {
    final motion = GlideMotion()..show(a, radius: 8);
    settle(motion);

    motion.follow(a.translate(0, -40));
    settle(motion);

    expect(
      motion.rect,
      rectMoreOrLessEquals(a.translate(0, -40), epsilon: 0.5),
    );
  });

  test('the corner morphs to the radius of the target', () {
    final motion = GlideMotion()..show(a, radius: 8);
    settle(motion);

    motion.moveTo(b, radius: 24, elapsedSinceLastMove: 1);
    settle(motion);

    expect(motion.corner, closeTo(24, 0.5));
  });

  test('fades out when the focus leaves and comes back in place', () {
    final motion = GlideMotion()..show(a, radius: 8);
    settle(motion);

    motion.hide();
    run(motion, 0.03);
    expect(motion.opacity, 1, reason: 'waits a moment');
    settle(motion);
    expect(motion.opacity, 0);
    expect(motion.visible, isFalse);
  });

  test('snaps without motion', () {
    final motion = GlideMotion()..snap(b, radius: 12);

    expect(motion.rect, b);
    expect(motion.opacity, 1);
    expect(motion.corner, 12);
    expect(motion.animating, isFalse);

    motion.snapHidden();
    expect(motion.visible, isFalse);
  });
}
