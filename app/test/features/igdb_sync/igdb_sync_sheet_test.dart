import 'dart:async';

import 'package:backlog_manager/api/sse.dart';
import 'package:backlog_manager/data/igdb_sync_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show game, pumpLibrary;

class FakeIgdbSyncApi implements IgdbSyncApi {
  FakeIgdbSyncApi({this.pending = 3});

  int pending;
  bool countFails = false;
  int syncs = 0;
  late StreamController<SseEvent> controller;
  Object? openError;

  @override
  Future<int> pendingCount() async {
    if (countFails) throw Exception('offline');
    return pending;
  }

  @override
  Stream<SseEvent> sync() {
    syncs++;
    controller = StreamController<SseEvent>();
    if (openError != null) {
      controller.addError(openError!);
      unawaited(controller.close());
    }
    return controller.stream;
  }
}

Future<(FakeIgdbSyncApi, FakeBacklogApi)> open(
  WidgetTester tester, {
  FakeIgdbSyncApi? sync,
}) async {
  final api = sync ?? FakeIgdbSyncApi();
  final backlog = FakeBacklogApi(entries: [game(1, 'Hades')]);
  await pumpLibrary(
    tester,
    backlog,
    overrides: [igdbSyncApiProvider.overrideWithValue(api)],
  );
  await tester.tap(find.byKey(const Key('igdb-sync-button')));
  await tester.pumpAndSettle();
  return (api, backlog);
}

Future<void> start(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('igdb-sync-start')));
  await tester.pump();
}

Future<void> dismissToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 6));

void main() {
  testWidgets('explains the sync and counts the games', (tester) async {
    await open(tester);

    expect(find.text('Sync IGDB game data'), findsOneWidget);
    expect(find.textContaining('never overwritten'), findsOneWidget);
    expect(find.text('3 games will be looked up.'), findsOneWidget);
  });

  testWidgets('says so when every game has data and disables Start', (
    tester,
  ) async {
    await open(tester, sync: FakeIgdbSyncApi(pending: 0));

    expect(find.text('Every game already has IGDB data.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('igdb-sync-start')));
    await tester.pump();
    expect(find.byKey(const Key('igdb-sync-progress')), findsNothing);
  });

  testWidgets('says so when the count fails', (tester) async {
    await open(tester, sync: FakeIgdbSyncApi()..countFails = true);

    expect(find.text('Could not count the games to sync.'), findsOneWidget);
  });

  testWidgets('shows progress and cannot be closed while it runs', (
    tester,
  ) async {
    final (api, _) = await open(tester);

    await start(tester);
    expect(find.text('Syncing...'), findsOneWidget);
    expect(find.text('Starting...'), findsOneWidget);

    api.controller.add(const SseProgress(2, 3));
    await tester.pump();
    expect(find.text('Looking up games 2/3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Sync IGDB game data'), findsOneWidget);

    await api.controller.close();
    await tester.pumpAndSettle();
    await dismissToast(tester);
  });

  testWidgets('reports the updated games, closes and reloads the entries', (
    tester,
  ) async {
    final (api, backlog) = await open(tester);
    final before = backlog.calls.where((c) => c.startsWith('entries')).length;

    await start(tester);
    api.controller.add(const SseDone(<Object?>[1, 2]));
    await tester.pumpAndSettle();

    expect(find.text('Updated 2 games with IGDB data'), findsOneWidget);
    expect(find.text('Sync IGDB game data'), findsNothing);
    expect(
      backlog.calls.where((c) => c.startsWith('entries')).length,
      greaterThan(before),
    );
    await dismissToast(tester);
  });

  testWidgets('says so when no data could be added', (tester) async {
    final (api, _) = await open(tester);

    await start(tester);
    api.controller.add(const SseDone([]));
    await tester.pumpAndSettle();

    expect(find.text('No IGDB data could be added'), findsOneWidget);
    await dismissToast(tester);
  });

  testWidgets('shows the message of the server and stays open', (tester) async {
    final (api, _) = await open(tester);

    await start(tester);
    api.controller.add(const SseError('IGDB is currently unreachable'));
    await tester.pumpAndSettle();

    expect(find.text('IGDB is currently unreachable'), findsOneWidget);
    expect(find.text('Sync IGDB game data'), findsOneWidget);
    expect(find.text('Start sync'), findsOneWidget);
    await dismissToast(tester);
  });

  testWidgets('names the missing credentials on a 503', (tester) async {
    final sync = FakeIgdbSyncApi()
      ..openError = DioException(
        requestOptions: RequestOptions(),
        response: Response(requestOptions: RequestOptions(), statusCode: 503),
      );
    await open(tester, sync: sync);

    await start(tester);
    await tester.pumpAndSettle();

    expect(find.text('IGDB integration is not configured'), findsOneWidget);
    await dismissToast(tester);
  });

  testWidgets('opens from the keyboard shortcut', (tester) async {
    final api = FakeIgdbSyncApi();
    await pumpLibrary(
      tester,
      FakeBacklogApi(entries: [game(1, 'Hades')]),
      overrides: [igdbSyncApiProvider.overrideWithValue(api)],
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('Sync IGDB game data'), findsOneWidget);
  });
}
