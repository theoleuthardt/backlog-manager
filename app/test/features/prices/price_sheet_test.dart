import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/game_info_providers.dart';
import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/price_listings.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/features/prices/price_sheet.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';

const ggDeals = 'https://gg.deals/game/hades/';

PriceInfo prices({
  double? retail = 12.5,
  double? keyshops = 8,
  double? historicalRetail = 7.99,
  double? historicalKeyshops = 6,
  String? url = ggDeals,
}) => PriceInfo(
  currency: 'EUR',
  currentRetail: retail,
  currentKeyshops: keyshops,
  historicalRetail: historicalRetail,
  historicalKeyshops: historicalKeyshops,
  url: url,
);

const royal = KeyShopOffer(
  shop: 'RoyalCDKeys',
  title: 'Hades',
  price: 8,
  currency: 'EUR',
  url: 'https://royal.example/hades',
  discountPct: 35,
);

Future<List<Uri>> pumpSheet(
  WidgetTester tester,
  FakeGamesApi api, {
  int? steamAppId = 1,
  String title = 'Hades',
}) async {
  final opened = <Uri>[];
  tester.view.physicalSize = const Size(600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        gamesApiProvider.overrideWithValue(api),
        urlOpenerProvider.overrideWithValue(opened.add),
        priceCacheTtlProvider.overrideWithValue(Duration.zero),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildShelfTheme(
          ShelfTokens.forTheme(resolveTheme('shelfOled', [])),
        ),
        home: Scaffold(
          body: PriceSheet(title: title, steamAppId: steamAppId),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  testWidgets('shows "Loading price..." while the prices load', (tester) async {
    final pending = Completer<PriceInfo>();
    final api = FakeGamesApi()..onPrice = (_) => pending.future;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [gamesApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildShelfTheme(
            ShelfTokens.forTheme(resolveTheme('shelfOled', [])),
          ),
          home: const Scaffold(body: PriceSheet(title: 'Hades', steamAppId: 1)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('price-loading')), findsOneWidget);
    pending.complete(prices());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('price-loading')), findsNothing);
  });

  testWidgets('says so when there is no price data and offers the search', (
    tester,
  ) async {
    await pumpSheet(tester, FakeGamesApi());

    expect(find.text('No price data available.'), findsOneWidget);
    expect(find.byKey(const Key('keyforsteam-row')), findsOneWidget);
  });

  testWidgets('falls back to the Keyforsteam search when GG.deals is down', (
    tester,
  ) async {
    final api = FakeGamesApi();
    api.onPrice = (_) async => throw const ApiException('down');
    api.onKeyShops = (_) async => throw const ApiException('down');

    final opened = await pumpSheet(tester, api, title: 'Hades II');

    expect(find.text('No price data available.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('keyforsteam-row')));
    await tester.pump();
    expect(
      opened.single.toString(),
      'https://www.google.com/search?q=site%3Akeyforsteam.de+Hades+II',
    );
  });

  testWidgets('keeps official store and keyshop prices apart', (tester) async {
    final api = FakeGamesApi()..onPrice = (_) async => prices();

    await pumpSheet(tester, api);

    expect(find.byKey(const Key('price-section-official')), findsOneWidget);
    expect(find.byKey(const Key('price-section-keyshops')), findsOneWidget);
    final official = tester.getTopLeft(
      find.byKey(const Key('price-official-now')),
    );
    final keyshops = tester.getTopLeft(
      find.byKey(const Key('price-keyshops-now')),
    );
    expect(
      official.dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('price-section-keyshops'))).dy,
      ),
    );
    expect(keyshops.dy, greaterThan(official.dy));
    expect(
      find.descendant(
        of: find.byKey(const Key('price-official-now')),
        matching: find.text('€12.50'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('price-official-ever')),
        matching: find.text('€7.99'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('price-keyshops-now')),
        matching: find.text('€8.00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('price-keyshops-ever')),
        matching: find.text('€6.00'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('leaves out a price GG.deals does not have', (tester) async {
    final api = FakeGamesApi()
      ..onPrice = (_) async => prices(retail: null, historicalRetail: null);

    await pumpSheet(tester, api);

    expect(find.byKey(const Key('price-section-official')), findsNothing);
    expect(find.byKey(const Key('price-keyshops-now')), findsOneWidget);
  });

  testWidgets('shows the banner when a price is at its lowest ever', (
    tester,
  ) async {
    final api = FakeGamesApi()
      ..onPrice = (_) async => prices(keyshops: 6, historicalKeyshops: 6);

    await pumpSheet(tester, api);

    expect(find.byKey(const Key('lowest-ever-banner')), findsOneWidget);
    expect(find.text('LOWEST PRICE EVER'), findsOneWidget);
    expect(find.textContaining('€6.00'), findsWidgets);
    expect(find.textContaining('keyshop'), findsWidgets);
  });

  testWidgets('has no banner while the prices are above the lowest', (
    tester,
  ) async {
    final api = FakeGamesApi()..onPrice = (_) async => prices();

    await pumpSheet(tester, api);

    expect(find.byKey(const Key('lowest-ever-banner')), findsNothing);
  });

  testWidgets('the rows and the attribution open the GG.deals page', (
    tester,
  ) async {
    final api = FakeGamesApi()..onPrice = (_) async => prices();
    final opened = await pumpSheet(tester, api);

    await tester.tap(find.byKey(const Key('price-official-now')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('gg-deals-attribution')));
    await tester.tap(find.byKey(const Key('gg-deals-attribution')));
    await tester.pump();

    expect(opened, [Uri.parse(ggDeals), Uri.parse(ggDeals)]);
  });

  testWidgets('credits GG.deals as the source of the prices', (tester) async {
    final api = FakeGamesApi()..onPrice = (_) async => prices();

    await pumpSheet(tester, api);

    expect(find.text('Prices by GG.deals'), findsOneWidget);
  });

  testWidgets('never opens a link that is not http or https', (tester) async {
    final api = FakeGamesApi()
      ..onPrice = (_) async => prices(url: 'javascript:alert(1)');
    final opened = await pumpSheet(tester, api);

    await tester.tap(find.byKey(const Key('price-official-now')));
    await tester.pump();

    expect(opened, isEmpty);
  });

  testWidgets('lists the key shop offers with the keyshops, cheapest first', (
    tester,
  ) async {
    final api = FakeGamesApi();
    api.onPrice = (_) async => prices();
    api.onKeyShops = (_) async => [
      royal,
      const KeyShopOffer(
        shop: 'PremiumCDKeys',
        title: 'Hades',
        price: 7,
        currency: 'EUR',
        url: 'https://premium.example/hades',
      ),
    ];

    await pumpSheet(tester, api);

    final tops = [
      for (final key in [
        'price-section-keyshops',
        'price-keyshop-PremiumCDKeys',
        'price-keyshop-RoyalCDKeys',
      ])
        tester.getTopLeft(find.byKey(Key(key))).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(find.textContaining('-35%'), findsOneWidget);
  });

  testWidgets('an offer row opens its link in the browser', (tester) async {
    final api = FakeGamesApi()..onKeyShops = (_) async => [royal];
    final opened = await pumpSheet(tester, api);

    await tester.tap(find.byKey(const Key('price-keyshop-RoyalCDKeys')));
    await tester.pump();

    expect(opened, [Uri.parse('https://royal.example/hades')]);
  });

  testWidgets('a game without a Steam App ID only asks the key shops', (
    tester,
  ) async {
    final api = FakeGamesApi()..onKeyShops = (_) async => [royal];

    await pumpSheet(tester, api, steamAppId: null);

    expect(api.calls, ['keys Hades']);
    expect(find.byKey(const Key('price-keyshop-RoyalCDKeys')), findsOneWidget);
    expect(find.byKey(const Key('gg-deals-attribution')), findsNothing);
  });

  testWidgets('golden: the price sheet', tags: 'golden', (tester) async {
    final api = FakeGamesApi();
    api.onPrice = (_) async => prices(keyshops: 6, historicalKeyshops: 6);
    api.onKeyShops = (_) async => [royal];
    await pumpSheet(tester, api);
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/royalcdkeys-icon.png'),
        tester.element(find.byType(PriceSheet)),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/price_sheet.png'),
    );
  });
}
