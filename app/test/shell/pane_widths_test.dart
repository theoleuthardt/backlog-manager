import 'dart:async';

import 'package:backlog_manager/shell/pane_widths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore implements PaneWidthStore {
  MemoryStore([Map<Pane, double>? saved]) : saved = saved ?? {};

  Map<Pane, double> saved;

  @override
  Future<Map<Pane, double>> read() async => saved;

  @override
  Future<void> write(Map<Pane, double> widths) async => saved = {...widths};
}

class SlowStore extends MemoryStore {
  SlowStore(super.saved);

  final loaded = Completer<void>();

  @override
  Future<Map<Pane, double>> read() async {
    final atRead = {...saved};
    await loaded.future;
    return atRead;
  }
}

ProviderContainer containerWith(MemoryStore store) {
  final container = ProviderContainer(
    overrides: [paneWidthStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('panes start at their default width', () {
    final container = containerWith(MemoryStore());

    expect(container.read(paneWidthProvider(Pane.sidebar)), 232);
    expect(container.read(paneWidthProvider(Pane.inspector)), 380);
  });

  test('resizing stays within the limits of the pane', () {
    final container = containerWith(MemoryStore());
    final notifier = container.read(paneWidthsProvider.notifier);

    notifier.resize(Pane.sidebar, 1000);
    expect(container.read(paneWidthProvider(Pane.sidebar)), Pane.sidebar.max);

    notifier.resize(Pane.sidebar, -1000);
    expect(container.read(paneWidthProvider(Pane.sidebar)), Pane.sidebar.min);
  });

  test('a committed width is kept and loaded again', () async {
    final store = MemoryStore();
    final first = containerWith(store);
    first
      ..read(paneWidthsProvider.notifier).resize(Pane.inspector, 100)
      ..read(paneWidthsProvider.notifier).commit();
    await Future<void>.delayed(Duration.zero);

    final second = containerWith(store);
    second.read(paneWidthsProvider);
    await Future<void>.delayed(Duration.zero);

    expect(second.read(paneWidthProvider(Pane.inspector)), 480);
  });

  test('resetting returns a pane to its default', () async {
    final store = MemoryStore({Pane.sidebar: 300});
    final container = containerWith(store);
    container.read(paneWidthsProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(paneWidthProvider(Pane.sidebar)), 300);

    container.read(paneWidthsProvider.notifier).reset(Pane.sidebar);

    expect(container.read(paneWidthProvider(Pane.sidebar)), 232);
    expect(store.saved.containsKey(Pane.sidebar), isFalse);
  });

  testWidgets(
    'dragging the handle resizes the pane and a double tap resets it',
    (tester) async {
      final store = MemoryStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [paneWidthStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: Row(
              children: [
                PaneResizeHandle(pane: Pane.sidebar, growsToRight: true),
              ],
            ),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      await tester.drag(
        find.byKey(const Key('resize-sidebar')),
        const Offset(40, 0),
      );
      await tester.pump();

      final dragged = container.read(paneWidthProvider(Pane.sidebar));
      expect(dragged, greaterThan(232));
      expect(store.saved[Pane.sidebar], dragged);

      final handle = find.byKey(const Key('resize-sidebar'));
      await tester.tap(handle);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(handle);
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(paneWidthProvider(Pane.sidebar)), 232);
    },
  );
}
