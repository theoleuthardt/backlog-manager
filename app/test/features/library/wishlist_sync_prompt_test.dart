import 'package:backlog_manager/data/wishlist_sync_api.dart';
import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/domain/wishlist_sync_report.dart';
import 'package:backlog_manager/features/library/wishlist_sync_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWishlistSyncApi implements WishlistSyncApi {
  FakeWishlistSyncApi(this.current);

  WishlistSyncReport current;
  int dismissed = 0;

  @override
  Future<WishlistSyncReport> report() async => current;

  @override
  Future<void> dismiss(DateTime updatedAt) async {
    dismissed++;
    current = const WishlistSyncReport();
  }
}

Future<void> pump(WidgetTester tester, WishlistSyncApi api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [wishlistSyncApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: buildShelfTheme(
          ShelfTokens.forTheme(resolveTheme('shelfOled', [])),
        ),
        home: const Scaffold(body: WishlistSyncPrompt(child: Text('library'))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final changed = WishlistSyncReport(
    since: DateTime.utc(2026, 10, 9),
    updatedAt: DateTime.utc(2026, 10, 10),
    added: const [WishlistChange(steamAppId: 620, title: 'Portal 2')],
    removed: const [WishlistChange(steamAppId: 10, title: 'Counter-Strike')],
  );

  testWidgets('shows the diff of what the sync changed', (tester) async {
    await pump(tester, FakeWishlistSyncApi(changed));

    expect(find.text('Your Steam wishlist changed'), findsOneWidget);
    expect(
      find.text('1 game added, 1 game removed since 9 Oct 2026'),
      findsOneWidget,
    );
    expect(find.text('+ Portal 2'), findsOneWidget);
    expect(find.text('- Counter-Strike'), findsOneWidget);
  });

  testWidgets('closing the sheet clears the report and shows it once', (
    tester,
  ) async {
    final api = FakeWishlistSyncApi(changed);
    await pump(tester, api);

    await tester.tap(find.byKey(const Key('wishlist-sync-close')));
    await tester.pumpAndSettle();

    expect(api.dismissed, 1);
    expect(find.text('Your Steam wishlist changed'), findsNothing);
    expect(find.text('library'), findsOneWidget);
  });

  testWidgets('stays out of the way when nothing changed', (tester) async {
    await pump(tester, FakeWishlistSyncApi(const WishlistSyncReport()));

    expect(find.text('Your Steam wishlist changed'), findsNothing);
  });
}
