import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

BacklogEntry game(int id, {String status = 'Not Started'}) =>
    BacklogEntry(id: id, title: 'Game $id', status: status);

void main() {
  late FakeBacklogApi api;
  late ProviderContainer container;

  ProviderContainer containerFor(FakeBacklogApi api) {
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [backlogApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    api = FakeBacklogApi(
      entries: [
        game(1),
        game(2),
        game(3, status: 'Completed'),
      ],
    );
    container = containerFor(api);
  });

  EntriesNotifier notifier([int? scope]) =>
      container.read(entriesProvider(scope).notifier);
  List<BacklogEntry> entries([int? scope]) =>
      container.read(entriesProvider(scope)).requireValue;
  Map<int, String> statuses([int? scope]) => {
    for (final e in entries(scope)) e.id: e.status,
  };

  Future<void> load([int? scope]) =>
      container.read(entriesProvider(scope).future);

  group('loading', () {
    test(
      'is loading first and then has the entries of the personal backlog',
      () async {
        expect(container.read(entriesProvider(null)).isLoading, isTrue);

        await load();

        expect(entries().map((e) => e.id), [1, 2, 3]);
        expect(api.calls, ['entries personal']);
      },
    );

    test('keeps the personal backlog and a space apart', () async {
      api.onEntries = (spaceId) async => [game(spaceId ?? 0)];

      await load();
      await load(7);

      expect(entries().single.id, 0);
      expect(entries(7).single.id, 7);
      expect(api.calls, ['entries personal', 'entries 7']);
    });

    test('shows the error of a failed load', () async {
      api.onEntries = (spaceId) async =>
          throw const ApiException('Server unavailable');

      await expectLater(
        container.read(entriesProvider(null).future),
        throwsA(isA<ApiException>()),
      );

      expect(container.read(entriesProvider(null)).hasError, isTrue);
    });

    test(
      'forgets the data of the previous user when the session changes',
      () async {
        await load();
        api.stored = {9: game(9)};

        container.read(sessionGenerationProvider.notifier).bump();
        await load();

        expect(entries().map((e) => e.id), [9]);
      },
    );
  });

  group('changing entries', () {
    test('creates an entry and reloads the list', () async {
      await load();

      await notifier().createEntry(
        const wire.CreateBacklogEntryRequest(
          title: 'Hades',
          genre: ['Roguelike'],
          platform: ['PC'],
          status: 'Not Started',
          owned: true,
          interest: 5,
        ),
      );

      expect(
        api.calls,
        containsAllInOrder(['create Hades', 'entries personal']),
      );
      expect(entries().map((e) => e.title), contains('Hades'));
    });

    test('updates an entry and reloads the list', () async {
      await load();

      await notifier().updateEntry(2, const EntryUpdate(status: 'Dropped'));

      expect(api.calls, contains('update 2 {status: Dropped}'));
      expect(statuses()[2], 'Dropped');
    });

    test('deletes an entry and reloads the list', () async {
      await load();

      await notifier().deleteEntry(1);

      expect(entries().map((e) => e.id), [2, 3]);
    });
  });

  group('moving an entry to a status', () {
    test(
      'changes the status at once and reloads when the request is done',
      () async {
        await load();
        final pending = Completer<void>();
        api.onUpdate = (id, update) => pending.future;

        final move = notifier().moveToStatus(1, 'In Progress');
        await Future<void>.delayed(Duration.zero);
        expect(statuses()[1], 'In Progress');
        expect(api.calls.where((c) => c.startsWith('entries')).length, 1);

        pending.complete();
        final error = await move;

        expect(error, isNull);
        expect(api.calls.where((c) => c.startsWith('entries')).length, 2);
        expect(statuses()[1], 'In Progress');
      },
    );

    test('puts a failed entry back and reports the message', () async {
      await load();
      api.onUpdate = (id, update) async =>
          throw const ApiException('Not allowed');

      final error = await notifier().moveToStatus(1, 'Completed');

      expect(error, 'Not allowed');
      expect(statuses()[1], 'Not Started');
    });

    test(
      'a failed move does not undo another move that is still running',
      () async {
        await load();
        final first = Completer<void>();
        final second = Completer<void>();
        api.onUpdate = (id, update) => id == 1 ? first.future : second.future;

        final moveOne = notifier().moveToStatus(1, 'Completed');
        final moveTwo = notifier().moveToStatus(2, 'In Progress');
        await Future<void>.delayed(Duration.zero);
        expect(statuses()[1], 'Completed');
        expect(statuses()[2], 'In Progress');

        first.completeError(const ApiException('Failed'));
        expect(await moveOne, 'Failed');
        expect(statuses()[1], 'Not Started');
        expect(statuses()[2], 'In Progress');

        second.complete();
        expect(await moveTwo, isNull);
        expect(statuses()[2], 'In Progress');
      },
    );

    test('reloads only once the last move is done', () async {
      await load();
      final first = Completer<void>();
      final second = Completer<void>();
      api.onUpdate = (id, update) => id == 1 ? first.future : second.future;

      final moveOne = notifier().moveToStatus(1, 'Completed');
      final moveTwo = notifier().moveToStatus(2, 'In Progress');
      await Future<void>.delayed(Duration.zero);

      first.complete();
      await moveOne;
      expect(api.calls.where((c) => c.startsWith('entries')).length, 1);

      second.complete();
      await moveTwo;
      expect(api.calls.where((c) => c.startsWith('entries')).length, 2);
    });
  });

  group('changing many entries', () {
    test(
      'sets a status with one request per entry and sums up the result',
      () async {
        await load();
        api.onUpdate = (id, update) async {
          if (id == 2) throw const ApiException('Failed');
        };

        final result = await notifier().setStatusOfMany([1, 2, 3], 'Dropped');

        expect(result.succeeded, [1, 3]);
        expect(result.failed, [2]);
        expect(api.calls.where((c) => c.startsWith('update')).length, 3);
        expect(api.calls.where((c) => c.startsWith('entries')).length, 2);
      },
    );

    test('deletes many entries with one request per entry', () async {
      await load();
      api.onDelete = (id) async {
        if (id == 1) throw const ApiException('Failed');
      };

      final result = await notifier().deleteMany([1, 2]);

      expect(result.succeeded, [2]);
      expect(result.failed, [1]);
      expect(entries().map((e) => e.id), [1, 3]);
    });
  });

  group('categories and statuses', () {
    test('lists the custom statuses of a scope', () async {
      api.statusList = const [CustomStatus(id: 1, name: 'Replaying')];

      final statuses = await container.read(
        customStatusesProvider(null).future,
      );

      expect(statuses.single.name, 'Replaying');
    });

    test('lists the categories of a scope', () async {
      api.categoryList = const [
        Category(id: 1, name: 'Co-op', color: '#38bdf8'),
      ];

      final categories = await container.read(categoriesProvider(null).future);

      expect(categories.single.name, 'Co-op');
    });

    test('maps every entry to its categories, alphabetical by name', () async {
      const zombies = Category(id: 1, name: 'zombies', color: '#111111');
      const arcade = Category(id: 2, name: 'Arcade', color: '#222222');
      api.categoryList = const [zombies, arcade];
      api.entriesByCategory = {
        1: [game(1), game(2)],
        2: [game(2)],
      };

      final byEntry = await container.read(
        entryCategoriesProvider(null).future,
      );

      expect(byEntry[1]!.map((c) => c.name), ['zombies']);
      expect(byEntry[2]!.map((c) => c.name), ['Arcade', 'zombies']);
      expect(byEntry[3], isNull);
    });
  });
}
