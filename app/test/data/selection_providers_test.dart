import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/selection_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  SelectionState state() => container.read(selectionProvider);
  SelectionNotifier notifier() => container.read(selectionProvider.notifier);

  test('starts without a selection', () {
    expect(state().active, isFalse);
    expect(state().ids, isEmpty);
  });

  test('begin turns selection mode on with nothing selected', () {
    notifier().begin();

    expect(state().active, isTrue);
    expect(state().ids, isEmpty);
  });

  test('start selects one game and turns the mode on', () {
    notifier().start(7);

    expect(state().active, isTrue);
    expect(state().ids, {7});
  });

  test('toggle adds a game and removes it again', () {
    notifier()
      ..begin()
      ..toggle(1)
      ..toggle(2);
    expect(state().ids, {1, 2});

    notifier().toggle(1);
    expect(state().ids, {2});
  });

  test('selectAll replaces the selection, clear empties it', () {
    notifier()
      ..start(9)
      ..selectAll([1, 2, 3]);
    expect(state().ids, {1, 2, 3});

    notifier().clear();
    expect(state().ids, isEmpty);
    expect(state().active, isTrue);
  });

  test('end leaves the mode and drops the selection', () {
    notifier()
      ..start(1)
      ..end();

    expect(state().active, isFalse);
    expect(state().ids, isEmpty);
  });

  test('removeAll drops games that are gone but keeps the mode', () {
    notifier()
      ..begin()
      ..selectAll([1, 2, 3])
      ..removeAll([2, 3]);

    expect(state().ids, {1});
    expect(state().active, isTrue);
  });

  test('is forgotten when the session changes', () {
    notifier().start(1);

    container.read(sessionGenerationProvider.notifier).bump();

    expect(state().active, isFalse);
    expect(state().ids, isEmpty);
  });
}
