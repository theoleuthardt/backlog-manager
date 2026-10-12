import 'package:backlog_manager/design/throttled_clock.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('notifies at most 30 times per second of a 60 Hz source', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(hours: 1),
    )..repeat();
    final clock = ThrottledClock(controller, period: const Duration(hours: 1));
    var notifications = 0;
    clock.addListener(() => notifications++);

    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(microseconds: 16667));
    }

    expect(notifications, inInclusiveRange(25, 31));
    clock.dispose();
    controller.dispose();
  });

  testWidgets('follows the source value', (tester) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 10),
    )..repeat();
    final clock = ThrottledClock(
      controller,
      period: const Duration(seconds: 10),
    );

    await tester.pump(const Duration(seconds: 5));

    expect(clock.value, closeTo(controller.value, 0.01));
    clock.dispose();
    controller.dispose();
  });
}
