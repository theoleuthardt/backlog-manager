import 'dart:async';

import 'package:backlog_manager/data/group_order_store.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import 'library_page_test.dart' show backlog, pumpLibrary;

class MemoryGroupOrderStore implements GroupOrderStore {
  MemoryGroupOrderStore([this.saved = const []]);

  List<String> saved;

  @override
  Future<List<String>> read() async => saved;

  @override
  Future<void> write(List<String> order) async => saved = order;
}

double top(WidgetTester tester, String groupKey) =>
    tester.getTopLeft(find.byKey(Key('group-$groupKey'))).dy;

Future<void> dragHandle(WidgetTester tester, String from, String onto) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(Key('group-handle-$from'))),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(const Offset(0, 24));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(find.byKey(Key('group-$onto'))));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

class SlowStore extends MemoryGroupOrderStore {
  SlowStore(super.saved);

  final loaded = Completer<void>();

  @override
  Future<List<String>> read() async {
    final atRead = saved;
    await loaded.future;
    return atRead;
  }
}

void main() {
  test(
    'keeps what was saved when the load finishes after a rearrange',
    () async {
      final store = SlowStore(['genre:RPG']);
      final container = ProviderContainer(
        overrides: [groupOrderStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(groupOrderProvider, (_, _) {});
      addTearDown(subscription.close);

      container.read(groupOrderProvider.notifier).arrange(['status:Completed']);
      store.loaded.complete();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(groupOrderProvider), [
        'status:Completed',
        'genre:RPG',
      ]);
      expect(store.saved, ['status:Completed', 'genre:RPG']);
    },
  );

  testWidgets('dragging the handle of a group moves it and saves the order', (
    tester,
  ) async {
    final store = MemoryGroupOrderStore();
    await pumpLibrary(
      tester,
      FakeBacklogApi(entries: backlog),
      overrides: [groupOrderStoreProvider.overrideWithValue(store)],
    );
    expect(
      top(tester, 'status:Not Started'),
      lessThan(top(tester, 'status:Completed')),
    );

    await dragHandle(tester, 'status:Completed', 'status:Not Started');

    expect(
      top(tester, 'status:Completed'),
      lessThan(top(tester, 'status:Not Started')),
    );
    expect(store.saved.first, 'status:Completed');
  });

  testWidgets('shows the saved order and resets it', (tester) async {
    final store = MemoryGroupOrderStore([
      'status:Completed',
      'status:Not Started',
    ]);
    await pumpLibrary(
      tester,
      FakeBacklogApi(entries: backlog),
      overrides: [groupOrderStoreProvider.overrideWithValue(store)],
    );

    expect(
      top(tester, 'status:Completed'),
      lessThan(top(tester, 'status:Not Started')),
    );

    await tester.tap(find.byKey(const Key('reset-group-order')));
    await tester.pumpAndSettle();

    expect(
      top(tester, 'status:Not Started'),
      lessThan(top(tester, 'status:Completed')),
    );
    expect(store.saved, isEmpty);
    expect(find.byKey(const Key('reset-group-order')), findsNothing);
  });

  testWidgets('offers no reset while the groups keep their order', (
    tester,
  ) async {
    await pumpLibrary(tester, FakeBacklogApi(entries: backlog));

    expect(find.byKey(const Key('reset-group-order')), findsNothing);
  });
}
