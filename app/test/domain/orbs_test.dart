import 'dart:math';

import 'package:backlog_manager/domain/orbs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('createOrbs', () {
    test('makes 28 orbs inside the window, alternating glow and accent', () {
      final orbs = createOrbs(const Size2(800, 600), Random(1));

      expect(orbs, hasLength(28));
      expect(orbs.first.useGlow, isTrue);
      expect(orbs[1].useGlow, isFalse);
      for (final orb in orbs) {
        expect(orb.x, inInclusiveRange(0, 800));
        expect(orb.y, inInclusiveRange(0, 600));
        expect(orb.radius, inInclusiveRange(40, 160));
        expect(orb.speedX.abs(), lessThanOrEqualTo(0.3));
        expect(orb.speedY.abs(), lessThanOrEqualTo(0.3));
      }
    });

    test('the same seed makes the same orbs', () {
      final first = createOrbs(const Size2(800, 600), Random(7));
      final second = createOrbs(const Size2(800, 600), Random(7));

      expect(first.map((o) => o.x), second.map((o) => o.x));
    });
  });

  group('Orb.step', () {
    const size = Size2(100, 100);

    test('drifts with its speed', () {
      final orb = Orb(
        x: 10,
        y: 20,
        radius: 50,
        speedX: 0.5,
        speedY: -0.25,
        phase: 0,
        useGlow: true,
      )..step(size);

      expect(orb.x, 10.5);
      expect(orb.y, 19.75);
    });

    test('comes back on the other side after leaving', () {
      final left = Orb(
        x: -49.9,
        y: 50,
        radius: 50,
        speedX: -0.5,
        speedY: 0,
        phase: 0,
        useGlow: true,
      )..step(size);
      final right = Orb(
        x: 149.9,
        y: 50,
        radius: 50,
        speedX: 0.5,
        speedY: 0,
        phase: 0,
        useGlow: true,
      )..step(size);
      final top = Orb(
        x: 50,
        y: -49.9,
        radius: 50,
        speedX: 0,
        speedY: -0.5,
        phase: 0,
        useGlow: true,
      )..step(size);
      final bottom = Orb(
        x: 50,
        y: 149.9,
        radius: 50,
        speedX: 0,
        speedY: 0.5,
        phase: 0,
        useGlow: true,
      )..step(size);

      expect(left.x, 150);
      expect(right.x, -50);
      expect(top.y, 150);
      expect(bottom.y, -50);
    });
  });

  group('Orb.step over time', () {
    Orb orbAt(double speedX) => Orb(
      x: 10,
      y: 10,
      radius: 50,
      speedX: speedX,
      speedY: 0,
      phase: 0,
      useGlow: true,
    );

    test('moves twice as far in two frames', () {
      final orb = orbAt(0.5)..step(const Size2(100, 100), frames: 2);

      expect(orb.x, 11);
    });

    test('moves half as far in half a frame', () {
      final orb = orbAt(0.5)..step(const Size2(100, 100), frames: 0.5);

      expect(orb.x, 10.25);
    });
  });

  group('respreadOrbs', () {
    Orb orbAt(double x, double y) => Orb(
      x: x,
      y: y,
      radius: 40,
      speedX: 0,
      speedY: 0,
      phase: 0,
      useGlow: true,
    );

    test('keeps the orbs in the same place of a window that grows', () {
      final orbs = [orbAt(50, 100)];

      respreadOrbs(orbs, const Size2(100, 200), const Size2(300, 400));

      expect(orbs.single.x, 150);
      expect(orbs.single.y, 200);
    });

    test('does nothing for a window that had no size', () {
      final orbs = [orbAt(5, 5)];

      respreadOrbs(orbs, const Size2(0, 0), const Size2(300, 400));

      expect(orbs.single.x, 5);
    });
  });

  group('pulse', () {
    test('stays between 50 and 100 percent of the radius', () {
      for (var frame = 0; frame < 500; frame++) {
        final value = orbPulse(frame.toDouble(), 1.3);
        expect(value, inInclusiveRange(0.5, 1.0));
      }
    });

    test('starts at 75 percent for phase 0', () {
      expect(orbPulse(0, 0), 0.75);
    });
  });
}
