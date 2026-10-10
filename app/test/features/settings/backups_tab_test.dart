import 'dart:async';
import 'dart:convert';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/backups_api.dart';
import 'package:backlog_manager/domain/backups.dart';
import 'package:backlog_manager/platform/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import 'settings_page_test.dart' show Settings, openSettings;

class FakeBackupsApi implements BackupsApi {
  FakeBackupsApi(List<Backup> backups) : backups = [...backups];

  List<Backup> backups;
  final calls = <String>[];
  Future<List<Backup>> Function()? onList;
  Future<RestoreResult> Function(int id)? onRestore;
  Future<void> Function(int id)? onDelete;
  Future<Backup> Function(int id, String? name)? onRename;
  Future<Uint8List> Function(int id)? onDownload;
  Future<Backup> Function()? onCreate;

  @override
  Future<List<Backup>> list() async {
    calls.add('list');
    return onList?.call() ?? Future.value([...backups]);
  }

  @override
  Future<Backup> create() async {
    calls.add('create');
    final custom = onCreate;
    final backup = custom == null
        ? await _make(backups.length + 10)
        : await custom();
    backups = [backup, ...backups];
    return backup;
  }

  Future<Backup> _make(int id) async => Backup(
    id: id,
    kind: 'manual',
    name: null,
    createdAt: DateTime.utc(2026, 10, 10, 12),
    entryCount: 3,
    categoryCount: 1,
  );

  @override
  Future<Backup> rename(int id, String? name) async {
    calls.add('rename $id ${name ?? '-'}');
    final custom = onRename;
    if (custom != null) return custom(id, name);
    final old = backups.firstWhere((b) => b.id == id);
    final renamed = Backup(
      id: id,
      kind: old.kind,
      name: name,
      createdAt: old.createdAt,
      entryCount: old.entryCount,
      categoryCount: old.categoryCount,
    );
    backups = [for (final b in backups) b.id == id ? renamed : b];
    return renamed;
  }

  @override
  Future<RestoreResult> restore(int id) async {
    calls.add('restore $id');
    return onRestore?.call(id) ??
        const RestoreResult(
          entryCount: 148,
          categoryCount: 3,
          safetyBackupId: 99,
        );
  }

  @override
  Future<void> delete(int id) async {
    calls.add('delete $id');
    await onDelete?.call(id);
    backups = [
      for (final b in backups)
        if (b.id != id) b,
    ];
  }

  @override
  Future<Uint8List> download(int id) async {
    calls.add('download $id');
    return onDownload?.call(id) ??
        Uint8List.fromList(utf8.encode('{"entries":[]}'));
  }
}

class FakeFileSaver implements FileSaver {
  final saved = <(String, List<int>)>[];
  bool cancel = false;

  @override
  Future<bool> save({
    required String suggestedName,
    required List<int> bytes,
  }) async {
    if (cancel) return false;
    saved.add((suggestedName, bytes));
    return true;
  }
}

final manual = Backup(
  id: 3,
  kind: 'manual',
  name: null,
  createdAt: DateTime.utc(2026, 10, 9, 8, 7),
  entryCount: 148,
  categoryCount: 3,
);

final named = Backup(
  id: 2,
  kind: 'auto',
  name: 'Before the move',
  createdAt: DateTime.utc(2026, 10, 8, 3),
  entryCount: 140,
  categoryCount: 1,
);

const backupsTab = '/settings?tab=backups';

Future<(Settings, FakeBackupsApi, FakeFileSaver, FakeBacklogApi)> open(
  WidgetTester tester, {
  List<Backup>? backups,
  void Function(FakeBackupsApi api)? setUp,
}) async {
  final api = FakeBackupsApi(backups ?? [manual, named]);
  setUp?.call(api);
  final saver = FakeFileSaver();
  final backlog = FakeBacklogApi();
  final settings = await openSettings(
    tester,
    location: backupsTab,
    overrides: [
      backupsApiProvider.overrideWithValue(api),
      fileSaverProvider.overrideWithValue(saver),
      backlogApiProvider.overrideWithValue(backlog),
    ],
  );
  return (settings, api, saver, backlog);
}

void main() {
  group('the list', () {
    testWidgets('shows the title, the date and the content of every backup', (
      tester,
    ) async {
      await open(tester);

      expect(find.textContaining('Manual'), findsWidgets);
      expect(find.textContaining('Before the move'), findsOneWidget);
      expect(find.text('148 games, 3 categories'), findsOneWidget);
      expect(find.text('Automatic - 140 games, 1 category'), findsOneWidget);
      expect(
        find.textContaining(backupDateLabel(manual.createdAt)),
        findsOneWidget,
      );
    });

    testWidgets('explains the automatic backups', (tester) async {
      await open(tester);

      expect(
        find.textContaining('backed up automatically once a day'),
        findsOneWidget,
      );
    });

    testWidgets('says so when there are none', (tester) async {
      await open(tester, backups: const []);

      expect(find.text('No backups yet.'), findsOneWidget);
    });

    testWidgets('says so when they cannot be loaded', (tester) async {
      await open(
        tester,
        setUp: (api) => api.onList = () async => throw Exception('offline'),
      );

      expect(find.text('Failed to load backups.'), findsOneWidget);
    });

    testWidgets('shows "Loading..." while they load', (tester) async {
      final pending = Completer<List<Backup>>();
      final api = FakeBackupsApi(const [])..onList = () => pending.future;
      await openSettings(
        tester,
        location: backupsTab,
        overrides: [backupsApiProvider.overrideWithValue(api)],
      );

      expect(find.byKey(const Key('backups-loading')), findsOneWidget);
      pending.complete(const []);
      await tester.pumpAndSettle();
    });
  });

  group('creating', () {
    testWidgets('makes a manual backup and lists it', (tester) async {
      final (_, api, _, _) = await open(tester);

      await tester.tap(find.byKey(const Key('backup-create')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('create'));
      expect(find.text('Backup created'), findsOneWidget);
      expect(find.byKey(const Key('backup-12')), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('shows the message of the backend when it fails', (
      tester,
    ) async {
      await open(
        tester,
        setUp: (api) =>
            api.onCreate = () async =>
                throw const ApiException('Backups are switched off'),
      );

      await tester.tap(find.byKey(const Key('backup-create')));
      await tester.pumpAndSettle();

      expect(find.text('Backups are switched off'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('renaming', () {
    testWidgets('saves the name from the field', (tester) async {
      final (_, api, _, _) = await open(tester);

      await tester.tap(find.byKey(const Key('backup-rename-3')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('backup-name')), '  Safe  ');
      await tester.tap(find.byKey(const Key('backup-name-save')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('rename 3 Safe'));
      expect(find.text('Backup renamed'), findsOneWidget);
      expect(find.byKey(const Key('backup-name')), findsNothing);
      expect(find.textContaining('Safe'), findsWidgets);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Enter saves and an empty name clears it', (tester) async {
      final (_, api, _, _) = await open(tester);

      await tester.tap(find.byKey(const Key('backup-rename-2')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('backup-name')))
            .controller!
            .text,
        'Before the move',
      );
      await tester.enterText(find.byKey(const Key('backup-name')), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(api.calls, contains('rename 2 -'));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('sends the name once however often Save is pressed', (
      tester,
    ) async {
      final gate = Completer<void>();
      final (_, api, _, _) = await open(
        tester,
        setUp: (api) => api.onRename = (id, name) async {
          await gate.future;
          return manual;
        },
      );

      await tester.tap(find.byKey(const Key('backup-rename-3')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('backup-name')), 'Safe');
      await tester.tap(find.byKey(const Key('backup-name-save')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('backup-name-save')));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(api.calls.where((c) => c.startsWith('rename')), hasLength(1));
      gate.complete();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Esc and Cancel leave the name alone', (tester) async {
      final (_, api, _, _) = await open(tester);

      await tester.tap(find.byKey(const Key('backup-rename-3')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('backup-name')), findsNothing);

      await tester.tap(find.byKey(const Key('backup-rename-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup-name-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('backup-name')), findsNothing);
      expect(api.calls.where((c) => c.startsWith('rename')), isEmpty);
    });

    testWidgets('stops at 60 characters', (tester) async {
      await open(tester);

      await tester.tap(find.byKey(const Key('backup-rename-3')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('backup-name')), 'x' * 80);

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('backup-name')))
            .controller!
            .text,
        hasLength(60),
      );
    });
  });

  group('restoring', () {
    testWidgets('names the date and the content before it does anything', (
      tester,
    ) async {
      final (_, api, _, _) = await open(tester);

      await tester.tap(find.byKey(const Key('backup-restore-3')));
      await tester.pumpAndSettle();

      expect(find.text('Restore this backup?'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('backup-restore-text'))).data,
        'Your current games, categories and custom statuses are replaced by '
        'the backup from ${backupDateLabel(manual.createdAt)} (148 games, 3 '
        'categories). Your current state is saved as a backup first, so you '
        'can undo this.',
      );
      expect(api.calls.where((c) => c.startsWith('restore')), isEmpty);
    });

    testWidgets('restores, tells how much came back and reloads the library', (
      tester,
    ) async {
      final (settings, api, _, backlog) = await open(tester);
      final subscription = settings.container.listen(
        entriesProvider(null),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await tester.pumpAndSettle();
      final before = backlog.calls.where((c) => c.startsWith('entries')).length;

      await tester.tap(find.byKey(const Key('backup-restore-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup-restore-confirm')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('restore 3'));
      expect(
        find.text(
          'Restored 148 games, 3 categories. Your previous state was saved as a '
          'backup.',
        ),
        findsOneWidget,
      );
      expect(
        backlog.calls.where((c) => c.startsWith('entries')).length,
        greaterThan(before),
      );
      expect(api.calls.where((c) => c == 'list').length, greaterThan(1));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('stays open with the message when it fails', (tester) async {
      await open(
        tester,
        setUp: (api) =>
            api.onRestore = (id) async =>
                throw const ApiException('The backup is damaged'),
      );

      await tester.tap(find.byKey(const Key('backup-restore-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup-restore-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('The backup is damaged'), findsOneWidget);
      expect(find.text('Restore this backup?'), findsOneWidget);
    });

    testWidgets('Cancel restores nothing', (tester) async {
      final (_, api, _, _) = await open(tester);

      await tester.tap(find.byKey(const Key('backup-restore-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Restore this backup?'), findsNothing);
      expect(api.calls.where((c) => c.startsWith('restore')), isEmpty);
    });
  });

  group('deleting', () {
    testWidgets('asks first and then removes the backup', (tester) async {
      final (_, api, _, _) = await open(tester);

      await tester.tap(find.byKey(const Key('backup-delete-3')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('backup-delete-text'))).data,
        '"Manual" from ${backupDateLabel(manual.createdAt)} (148 games, 3 '
        'categories) is removed permanently. This cannot be undone.',
      );
      expect(api.calls.where((c) => c.startsWith('delete')), isEmpty);

      await tester.tap(find.byKey(const Key('backup-delete-confirm')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('delete 3'));
      expect(find.text('Backup deleted'), findsOneWidget);
      expect(find.byKey(const Key('backup-3')), findsNothing);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('keeps the backup when the server refuses', (tester) async {
      await open(
        tester,
        setUp: (api) =>
            api.onDelete = (id) async =>
                throw const ApiException('Not allowed'),
      );

      await tester.tap(find.byKey(const Key('backup-delete-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup-delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Not allowed'), findsOneWidget);
      expect(find.byKey(const Key('backup-3')), findsOneWidget);
    });
  });

  group('downloading', () {
    testWidgets('saves the file under the name of the backup', (tester) async {
      final (_, api, saver, _) = await open(tester);

      await tester.tap(find.byKey(const Key('backup-download-3')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('download 3'));
      expect(saver.saved.single.$1, 'backlog-backup-3.json');
      expect(utf8.decode(saver.saved.single.$2), '{"entries":[]}');
      expect(find.text('Backup saved'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('says nothing when the user cancels the dialog', (
      tester,
    ) async {
      final (_, _, saver, _) = await open(tester);
      saver.cancel = true;

      await tester.tap(find.byKey(const Key('backup-download-3')));
      await tester.pumpAndSettle();

      expect(find.text('Backup saved'), findsNothing);
    });

    testWidgets('shows the message when the download fails', (tester) async {
      await open(
        tester,
        setUp: (api) =>
            api.onDownload = (id) async =>
                throw const ApiException('Backup not found'),
      );

      await tester.tap(find.byKey(const Key('backup-download-3')));
      await tester.pumpAndSettle();

      expect(find.text('Backup not found'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  testWidgets('golden: the backups', tags: 'golden', (tester) async {
    await open(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/backups.png'),
    );
  });
}
