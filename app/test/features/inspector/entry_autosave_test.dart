import 'dart:async';

import 'package:backlog_manager/domain/entry_changes.dart';
import 'package:backlog_manager/features/inspector/entry_autosave.dart';
import 'package:flutter_test/flutter_test.dart';

const delay = Duration(milliseconds: 30);

Future<void> wait([int factor = 3]) => Future<void>.delayed(delay * factor);

class Harness {
  Harness() {
    autosave = EntryAutosave(
      delay: delay,
      pending: () => pending,
      save: (changes) async {
        saves.add(changes);
        final gate = gates.isEmpty ? null : gates.removeAt(0);
        if (gate != null) await gate.future;
        final failure = failures.isEmpty ? null : failures.removeAt(0);
        if (failure != null) throw failure;
        stored = changes.note ?? stored;
        if (pending.note == stored) pending = const EntryFormChanges();
      },
      onError: errors.add,
    );
  }

  late final EntryAutosave autosave;
  EntryFormChanges pending = const EntryFormChanges();
  String stored = '';
  final saves = <EntryFormChanges>[];
  final gates = <Completer<void>>[];
  final failures = <Object>[];
  final errors = <Object>[];

  void edit(String note) {
    pending = EntryFormChanges(note: note);
    autosave.changed();
  }
}

void main() {
  test('saves once, a moment after the last change', () async {
    final h = Harness();
    addTearDown(h.autosave.dispose);

    h
      ..edit('a')
      ..edit('ab')
      ..edit('abc');
    expect(h.saves, isEmpty);
    await wait(2);

    expect(h.saves.map((c) => c.note), ['abc']);
    expect(h.autosave.state.value, SaveState.saved);
  });

  test('saves nothing when there is nothing to save', () async {
    final h = Harness();
    addTearDown(h.autosave.dispose);

    h.autosave.changed();
    await wait();

    expect(h.saves, isEmpty);
    expect(h.autosave.state.value, SaveState.idle);
  });

  test('is saving while the request runs', () async {
    final h = Harness();
    addTearDown(h.autosave.dispose);
    final gate = Completer<void>();
    h.gates.add(gate);

    h.edit('a');
    await wait(2);
    expect(h.autosave.state.value, SaveState.saving);

    gate.complete();
    await wait(2);
    expect(h.autosave.state.value, SaveState.saved);
  });

  test('saves edits that arrive during a running save afterwards', () async {
    final h = Harness();
    addTearDown(h.autosave.dispose);
    final gate = Completer<void>();
    h.gates.add(gate);

    h.edit('a');
    await wait(2);
    h.edit('ab');
    await wait(3);
    expect(h.saves, hasLength(1));

    gate.complete();
    await wait(4);

    expect(h.saves.map((c) => c.note), ['a', 'ab']);
    expect(h.stored, 'ab');
  });

  test('a failed save reports the error and keeps the changes', () async {
    final h = Harness();
    addTearDown(h.autosave.dispose);
    h.failures.add(Exception('offline'));

    h.edit('a');
    await wait(3);

    expect(h.autosave.state.value, SaveState.error);
    expect(h.errors, hasLength(1));
    expect(h.saves, hasLength(1));
  });

  test('the next change after a failure saves again', () async {
    final h = Harness();
    addTearDown(h.autosave.dispose);
    h.failures.add(Exception('offline'));

    h.edit('a');
    await wait(3);
    h.edit('ab');
    await wait(3);

    expect(h.saves.map((c) => c.note), ['a', 'ab']);
    expect(h.autosave.state.value, SaveState.saved);
  });

  test('flush saves what is pending at once', () async {
    final h = Harness();

    h.edit('a');
    h.autosave.flush();
    await wait(1);

    expect(h.saves.map((c) => c.note), ['a']);
    h.autosave.dispose();
  });

  test('flush does not start a second save while one runs', () async {
    final h = Harness();
    final gate = Completer<void>();
    h.gates.add(gate);

    h.edit('a');
    await wait(2);
    h.edit('ab');
    h.autosave.flush();

    expect(h.saves, hasLength(1));
    gate.complete();
    await wait(2);
    h.autosave.dispose();
  });

  test('a disposed autosave saves nothing more', () async {
    final h = Harness();

    h.edit('a');
    h.autosave.dispose();
    await wait(3);

    expect(h.saves, isEmpty);
  });
}
