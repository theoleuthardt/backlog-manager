import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/common/status_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../../design/widgets/harness.dart';

class Host extends StatefulWidget {
  const Host({required this.initial, this.spaceId, super.key});

  final String initial;
  final int? spaceId;

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  late String value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return StatusSelect(
      value: value,
      spaceId: widget.spaceId,
      onChanged: (next) => setState(() => value = next),
    );
  }
}

Future<FakeBacklogApi> pumpSelect(
  WidgetTester tester, {
  String value = 'Not Started',
  List<CustomStatus> custom = const [
    CustomStatus(id: 1, name: 'Replaying'),
    CustomStatus(id: 2, name: 'Wishlist'),
  ],
  int? spaceId,
}) async {
  final api = FakeBacklogApi()..statusList = custom;
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [backlogApiProvider.overrideWithValue(api)],
      child: themed(
        'shelfOled',
        Host(initial: value, spaceId: spaceId),
        width: 320,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

String current(WidgetTester tester) =>
    tester.state<HostState>(find.byType(Host)).value;

Future<void> open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('status-select')));
  await tester.pumpAndSettle();
}

void main() {
  group('the trigger', () {
    testWidgets('shows the selected status', (tester) async {
      await pumpSelect(tester, value: 'Completed');

      expect(
        find.descendant(
          of: find.byKey(const Key('status-select')),
          matching: find.text('Completed'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows the placeholder without a value', (tester) async {
      await pumpSelect(tester, value: '');

      expect(find.text('Select status'), findsOneWidget);
    });
  });

  group('the options', () {
    testWidgets('list the defaults first, then the custom statuses', (
      tester,
    ) async {
      await pumpSelect(tester);
      await open(tester);

      final labels = [
        'Not Started',
        'In Progress',
        'Completed',
        'On Hold',
        'Dropped',
        'Replaying',
        'Wishlist',
      ];
      final tops = [
        for (final label in labels)
          tester.getTopLeft(find.byKey(Key('status-option-$label'))).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(find.byKey(const Key('status-add')), findsOneWidget);
    });

    testWidgets('show a delete button for custom statuses only', (
      tester,
    ) async {
      await pumpSelect(tester);
      await open(tester);

      expect(find.byKey(const Key('status-delete-Replaying')), findsOneWidget);
      expect(find.byKey(const Key('status-delete-Wishlist')), findsOneWidget);
      expect(find.byKey(const Key('status-delete-Completed')), findsNothing);
    });

    testWidgets('add the value of an entry that is not a known status', (
      tester,
    ) async {
      await pumpSelect(tester, value: 'Imported');
      await open(tester);

      expect(find.byKey(const Key('status-option-Imported')), findsOneWidget);
      expect(find.byKey(const Key('status-delete-Imported')), findsNothing);
    });

    testWidgets('choosing one selects it and closes the list', (tester) async {
      await pumpSelect(tester);
      await open(tester);

      await tester.tap(find.byKey(const Key('status-option-Replaying')));
      await tester.pumpAndSettle();

      expect(current(tester), 'Replaying');
      expect(find.byKey(const Key('status-option-Dropped')), findsNothing);
    });
  });

  group('deleting a custom status', () {
    testWidgets('removes it and tells the user', (tester) async {
      final api = await pumpSelect(tester);
      await open(tester);

      await tester.tap(find.byKey(const Key('status-delete-Wishlist')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('delete-status 2 personal'));
      expect(find.text('Status "Wishlist" deleted'), findsOneWidget);
      expect(current(tester), 'Not Started');
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('clears the field when it was the selected status', (
      tester,
    ) async {
      await pumpSelect(tester, value: 'Replaying');
      await open(tester);

      await tester.tap(find.byKey(const Key('status-delete-Replaying')));
      await tester.pumpAndSettle();

      expect(current(tester), '');
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('adding a status', () {
    Future<void> openSheet(WidgetTester tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('status-add')));
      await tester.pumpAndSettle();
    }

    Future<void> type(WidgetTester tester, String name) async {
      await tester.enterText(find.byKey(const Key('status-name-field')), name);
      await tester.pumpAndSettle();
    }

    testWidgets('creates the status, selects it and shows a toast', (
      tester,
    ) async {
      final api = await pumpSelect(tester);
      await openSheet(tester);

      await type(tester, '  Backlog 2  ');
      await tester.tap(find.byKey(const Key('status-create')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('create-status Backlog 2 personal'));
      expect(current(tester), 'Backlog 2');
      expect(find.byKey(const Key('status-name-field')), findsNothing);
      expect(find.text('Status "Backlog 2" created'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('submits with Enter', (tester) async {
      final api = await pumpSelect(tester);
      await openSheet(tester);

      await type(tester, 'Parked');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(api.calls, contains('create-status Parked personal'));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('validates while typing and blocks the button', (tester) async {
      final api = await pumpSelect(tester);
      await openSheet(tester);

      await type(tester, 'a' * 21);
      expect(find.text('Max 20 characters'), findsOneWidget);

      await type(tester, 'Completed');
      expect(find.text("That's already a default status"), findsOneWidget);

      await type(tester, 'Replaying');
      expect(
        find.text('You already have a status with that name'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('status-create')));
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c.startsWith('create-status')), isEmpty);
      expect(find.byKey(const Key('status-name-field')), findsOneWidget);
    });

    testWidgets('does nothing for an empty name', (tester) async {
      final api = await pumpSelect(tester);
      await openSheet(tester);

      await tester.tap(find.byKey(const Key('status-create')));
      await tester.pumpAndSettle();

      expect(api.calls.where((c) => c.startsWith('create-status')), isEmpty);
    });
  });

  group('in a shared space', () {
    testWidgets('lists and creates the statuses of that space', (tester) async {
      final api = await pumpSelect(tester, spaceId: 4);
      await open(tester);
      expect(api.calls, contains('statuses 4'));

      await tester.tap(find.byKey(const Key('status-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('status-name-field')),
        'Co-op',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('status-create')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('create-status Co-op 4'));
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
