import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/chips.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/design/widgets/stepper.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/features/gallery/gallery_routes.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class SignedIn extends SessionNotifier {
  @override
  SessionState build() => const SessionSignedIn(
    SessionUser(name: 'Theo', email: 'theo@example.com', setupCompleted: true),
  );
}

Future<ProviderContainer> openGallery(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(SignedIn.new)],
      child: const BacklogManagerApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  container.read(routerProvider).go(AppRoutes.gallery);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  test('registers the gallery route only when it is enabled', () {
    expect(galleryRoutes(enabled: true), hasLength(1));
    expect(galleryRoutes(enabled: false), isEmpty);
  });

  testWidgets('lists every kind of component', (tester) async {
    await openGallery(tester);

    expect(find.byKey(const Key('page-gallery')), findsOneWidget);
    for (final type in [
      ShelfButton,
      ShelfChip,
      ShelfSwitch,
      ShelfCheckbox,
      ShelfCover,
      ShelfStepper,
    ]) {
      expect(find.byType(type), findsWidgets, reason: '$type');
    }
    expect(find.byKey(const Key('table-header')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens a sheet and a toast from its buttons', (tester) async {
    await openGallery(tester);

    await tester.ensureVisible(find.text('Open a sheet'));
    await tester.tap(find.text('Open a sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Add a game'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('sheet-surface')),
        matching: find.byTooltip('Close'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Show a toast'));
    await tester.tap(find.text('Show a toast'));
    await tester.pump();
    expect(find.text('Moved to Completed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
