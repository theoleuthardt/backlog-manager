import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/random_pull.dart';
import 'package:backlog_manager/features/random_pull/slot_reel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design/widgets/harness.dart';

void main() {
  testWidgets('stops on the pulled game also under a safe-area inset', (
    tester,
  ) async {
    const strip = ReelStrip(
      games: [
        BacklogEntry(id: 1, title: 'Alpha'),
        BacklogEntry(id: 2, title: 'Bravo'),
        BacklogEntry(id: 3, title: 'Charlie'),
        BacklogEntry(id: 4, title: 'Delta'),
        BacklogEntry(id: 5, title: 'Echo'),
      ],
      stopIndex: 3,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: themed(
          'shelfOled',
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 59, bottom: 34)),
              child: SlotReel(strip: strip, onDone: () {}),
            ),
          ),
          width: 360,
        ),
      ),
    );
    await tester.pump(slotReelDuration + const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    final reel = tester.getRect(find.byKey(const Key('random-pull-reel')));
    final middle = reel.center.dy;
    final picked = tester.getRect(find.text('Delta'));
    expect(
      picked.center.dy,
      closeTo(middle, 8),
      reason: 'the pulled game sits on the highlighted middle row',
    );
  });
}
