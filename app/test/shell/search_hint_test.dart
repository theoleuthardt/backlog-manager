import 'package:backlog_manager/design/background_motion.dart';
import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/search_hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore implements BackgroundMotionStore {
  MemoryStore({this.seen});

  bool? seen;

  @override
  Future<bool?> read() async => seen;

  @override
  Future<void> write({required bool enabled}) async => seen = enabled;
}

Future<void> pumpHint(
  WidgetTester tester, {
  required MemoryStore store,
  String location = AppRoutes.library,
  TargetPlatform platform = TargetPlatform.windows,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [searchHintStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        theme: buildShelfTheme(
          ShelfTokens.forTheme(resolveTheme('shelfOled', [])),
        ).copyWith(platform: platform),
        home: SearchHintPrompt(
          location: location,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => searchHintEnabled = true);
  tearDown(() => searchHintEnabled = false);

  testWidgets('shows the hint once in the library and remembers it', (
    tester,
  ) async {
    final store = MemoryStore();
    await pumpHint(tester, store: store);

    expect(find.textContaining('Ctrl+K'), findsOneWidget);
    expect(find.textContaining('Ctrl+S'), findsOneWidget);
    expect(store.seen, isTrue);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('names the Command key on macOS', (tester) async {
    await pumpHint(
      tester,
      store: MemoryStore(),
      platform: TargetPlatform.macOS,
    );

    expect(find.textContaining('⌘K'), findsOneWidget);
    expect(find.textContaining('⌘S'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('does not show it again once it was seen', (tester) async {
    await pumpHint(tester, store: MemoryStore(seen: true));

    expect(find.textContaining('Ctrl+K'), findsNothing);
  });

  testWidgets('waits for the library', (tester) async {
    final store = MemoryStore();
    await pumpHint(tester, store: store, location: AppRoutes.home);

    expect(find.textContaining('Ctrl+K'), findsNothing);
    expect(store.seen, isNull);
  });

  testWidgets('is off in tests unless a test asks for it', (tester) async {
    searchHintEnabled = false;
    await pumpHint(tester, store: MemoryStore());

    expect(find.textContaining('Ctrl+K'), findsNothing);
  });
}
