import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/domain/space_backups.dart';
import 'package:backlog_manager/platform/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../settings/backups_tab_test.dart' show FakeFileSaver;
import 'space_page_test.dart' show Opened, dismissToast, open, together;

final daily = SpaceBackup(
  id: 3,
  kind: 'auto',
  name: null,
  createdAt: DateTime.utc(2026, 10, 18, 8),
  entryCount: 4,
  categoryCount: 1,
  createdBy: null,
);

final named = SpaceBackup(
  id: 2,
  kind: 'manual',
  name: 'Before the move',
  createdAt: DateTime.utc(2026, 10, 17, 20),
  entryCount: 5,
  categoryCount: 2,
  createdBy: 'alex',
);

RestoreRequest fromPartner() => RestoreRequest(
  id: 70,
  backupId: 2,
  backupName: 'Before the move',
  backupCreatedAt: DateTime.utc(2026, 10, 17, 20),
  requestedBy: 'alex',
  requestedByMe: false,
  createdAt: DateTime.utc(2026, 10, 19, 9),
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 20, minutes: 30)),
);

Future<({FakeSpaceBackupsApi api, FakeFileSaver saver, Opened opened})>
openSheet(
  WidgetTester tester, {
  FakeSpaceBackupsApi? api,
  bool sheet = true,
}) async {
  final backups = api ?? FakeSpaceBackupsApi(backups: [daily, named]);
  final saver = FakeFileSaver();
  final opened = await open(
    tester,
    together,
    backupsApi: backups,
    overrides: [fileSaverProvider.overrideWithValue(saver)],
  );
  if (sheet) {
    await tester.tap(find.byKey(const Key('space-backups-button')));
    await tester.pumpAndSettle();
  }
  return (api: backups, saver: saver, opened: opened);
}

void main() {
  group('the button', () {
    testWidgets('is in the toolbar of the space and opens the backups', (
      tester,
    ) async {
      await openSheet(tester, sheet: false);

      expect(find.byKey(const Key('space-backups-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('space-backups-button')));
      await tester.pumpAndSettle();

      expect(find.text('Space backups'), findsOneWidget);
    });

    testWidgets('has no dot while nothing waits for me', (tester) async {
      await openSheet(tester, sheet: false);

      expect(find.byKey(const Key('space-backups-waiting')), findsNothing);
    });

    testWidgets('has a dot while the partner waits for my approval', (
      tester,
    ) async {
      await openSheet(
        tester,
        sheet: false,
        api: FakeSpaceBackupsApi(backups: [named], request: fromPartner()),
      );

      expect(find.byKey(const Key('space-backups-waiting')), findsOneWidget);
    });
  });

  group('the list', () {
    testWidgets('shows every backup with its kind, author and content', (
      tester,
    ) async {
      await openSheet(tester);

      expect(find.textContaining('Automatic'), findsWidgets);
      expect(find.text('Automatic - 4 games, 1 category'), findsOneWidget);
      expect(find.textContaining('Before the move'), findsOneWidget);
      expect(
        find.text('Manual by alex - 5 games, 2 categories'),
        findsOneWidget,
      );
    });

    testWidgets('says so when there is none', (tester) async {
      await openSheet(tester, api: FakeSpaceBackupsApi());

      expect(find.byKey(const Key('space-backups-empty')), findsOneWidget);
    });

    testWidgets('explains that a restore needs both members', (tester) async {
      await openSheet(tester);

      expect(find.textContaining('both of you'), findsOneWidget);
    });
  });

  group('taking and keeping backups', () {
    testWidgets('Back up now creates one and refreshes the list', (
      tester,
    ) async {
      final setup = await openSheet(tester);

      await tester.tap(find.byKey(const Key('space-backup-create')));
      await tester.pumpAndSettle();

      expect(setup.api.calls, contains('create'));
      expect(find.byKey(const Key('space-backup-12')), findsOneWidget);
      expect(find.text('Backup created'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('Export saves the JSON file of the space', (tester) async {
      final setup = await openSheet(tester);

      await tester.tap(find.byKey(const Key('space-export')));
      await tester.pumpAndSettle();

      expect(setup.api.calls, contains('export'));
      expect(setup.saver.saved.single.$1, 'space-backlog.json');
      expect(find.text('Export saved'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('Download saves the file of one backup', (tester) async {
      final setup = await openSheet(tester);

      await tester.tap(find.byKey(const Key('space-backup-download-2')));
      await tester.pumpAndSettle();

      expect(setup.saver.saved.single.$1, 'space-backup-2.json');
      expect(find.text('Backup saved'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('Rename sets the name', (tester) async {
      final setup = await openSheet(tester);

      await tester.tap(find.byKey(const Key('space-backup-rename-3')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('space-backup-name')),
        '  Before the sale ',
      );
      await tester.tap(find.byKey(const Key('space-backup-name-save')));
      await tester.pumpAndSettle();

      expect(setup.api.calls, contains('rename 3 Before the sale'));
      expect(find.textContaining('Before the sale'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('Delete asks first and then removes the backup', (
      tester,
    ) async {
      final setup = await openSheet(tester);

      await tester.tap(find.byKey(const Key('space-backup-delete-3')));
      await tester.pumpAndSettle();
      expect(find.textContaining('removed permanently'), findsOneWidget);
      await tester.tap(find.byKey(const Key('space-backup-delete-confirm')));
      await tester.pumpAndSettle();

      expect(setup.api.calls, contains('delete 3'));
      expect(find.byKey(const Key('space-backup-3')), findsNothing);
      await dismissToast(tester);
    });
  });

  group('asking for a restore', () {
    testWidgets('says that the partner has to approve it', (tester) async {
      await openSheet(tester);

      await tester.tap(find.byKey(const Key('space-backup-restore-2')));
      await tester.pumpAndSettle();

      expect(find.textContaining('alex has to approve'), findsOneWidget);
    });

    testWidgets('sends the request and shows who it waits for', (tester) async {
      final setup = await openSheet(tester);

      await tester.tap(find.byKey(const Key('space-backup-restore-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('space-backup-restore-confirm')));
      await tester.pumpAndSettle();

      expect(setup.api.calls, contains('request-restore 2'));
      expect(
        find.text('Waiting for alex to approve restoring "Before the move".'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('space-restore-withdraw')), findsOneWidget);
      expect(find.byKey(const Key('space-restore-approve')), findsNothing);
      expect(find.text('Restore requested'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('the member who asked can take the request back', (
      tester,
    ) async {
      final setup = await openSheet(tester);
      await tester.tap(find.byKey(const Key('space-backup-restore-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('space-backup-restore-confirm')));
      await tester.pumpAndSettle();
      await dismissToast(tester);

      await tester.tap(find.byKey(const Key('space-restore-withdraw')));
      await tester.pumpAndSettle();

      expect(setup.api.calls, contains('withdraw-restore'));
      expect(find.byKey(const Key('space-restore-request')), findsNothing);
    });

    testWidgets('no second restore can be asked for while one waits', (
      tester,
    ) async {
      await openSheet(
        tester,
        api: FakeSpaceBackupsApi(
          backups: [daily, named],
          request: fromPartner(),
        ),
      );

      final button = tester.widget<ShelfButton>(
        find.byKey(const Key('space-backup-restore-3')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a space with one member restores at once', (tester) async {
      final api = FakeSpaceBackupsApi(backups: [daily, named])
        ..restoresAtOnce = true;
      final setup = await openSheet(tester, api: api);
      final entriesBefore = setup.opened.backlog.calls
          .where((call) => call.startsWith('entries'))
          .length;

      await tester.tap(find.byKey(const Key('space-backup-restore-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('space-backup-restore-confirm')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Restored'), findsOneWidget);
      expect(
        setup.opened.backlog.calls
            .where((call) => call.startsWith('entries'))
            .length,
        greaterThan(entriesBefore),
      );
      await dismissToast(tester);
    });

    testWidgets('shows the message of the server when it refuses', (
      tester,
    ) async {
      final api = FakeSpaceBackupsApi(backups: [daily, named]);
      await openSheet(tester, api: api);
      api.error = Exception('boom');

      await tester.tap(find.byKey(const Key('space-backup-restore-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('space-backup-restore-confirm')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('space-backup-restore-error')),
        findsOneWidget,
      );
    });
  });

  group('a restore the partner asked for', () {
    FakeSpaceBackupsApi waitingApi() =>
        FakeSpaceBackupsApi(backups: [daily, named], request: fromPartner());

    testWidgets('is shown with Approve and Decline', (tester) async {
      await openSheet(tester, api: waitingApi());

      expect(
        find.text('alex wants to restore "Before the move".'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('space-restore-approve')), findsOneWidget);
      expect(find.byKey(const Key('space-restore-decline')), findsOneWidget);
      expect(find.byKey(const Key('space-restore-withdraw')), findsNothing);
    });

    testWidgets('Approve runs it and reloads the games of the space', (
      tester,
    ) async {
      final api = waitingApi();
      final setup = await openSheet(tester, api: api);
      final entriesBefore = setup.opened.backlog.calls
          .where((call) => call.startsWith('entries'))
          .length;

      await tester.tap(find.byKey(const Key('space-restore-approve')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('approve-restore'));
      expect(find.textContaining('Restored 5 games'), findsOneWidget);
      expect(find.byKey(const Key('space-restore-request')), findsNothing);
      expect(
        setup.opened.backlog.calls
            .where((call) => call.startsWith('entries'))
            .length,
        greaterThan(entriesBefore),
      );
      await dismissToast(tester);
    });

    testWidgets('Decline ends the request', (tester) async {
      final api = waitingApi();
      await openSheet(tester, api: api);

      await tester.tap(find.byKey(const Key('space-restore-decline')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('withdraw-restore'));
      expect(find.byKey(const Key('space-restore-request')), findsNothing);
    });

    testWidgets('shows up while the sheet is open', (tester) async {
      final api = FakeSpaceBackupsApi(backups: [daily, named]);
      await openSheet(tester, api: api);
      expect(find.byKey(const Key('space-restore-request')), findsNothing);

      api.request = fromPartner();
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('space-restore-request')), findsOneWidget);
    });
  });

  testWidgets('golden: the space backups', tags: 'golden', (tester) async {
    await openSheet(
      tester,
      api: FakeSpaceBackupsApi(backups: [daily, named], request: fromPartner()),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/space_backups.png'),
    );
  });
}
