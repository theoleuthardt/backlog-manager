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

PriceInfo prices(List<PriceDeal> deals, {bool onSale = false, double? ever}) =>
    PriceInfo(deals: deals, onSale: onSale, cheapestPriceEver: ever);

const steam = PriceDeal(
  store: 'Steam',
  iconUrl: 'https://cdn.example/steam.png',
  price: 12.5,
  retailPrice: 25,
  url: 'https://store.steampowered.com/app/1',
);
const gog = PriceDeal(
  store: 'GOG',
  iconUrl: 'https://cdn.example/gog.png',
  price: 10,
  retailPrice: 25,
  url: 'https://www.gog.com/game/1',
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
  tester.view.physicalSize = const Size(600, 560);
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
    pending.complete(prices([]));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('price-loading')), findsNothing);
  });

  testWidgets('says so when there is no price data', (tester) async {
    await pumpSheet(tester, FakeGamesApi());

    expect(find.text('No price data available.'), findsOneWidget);
  });

  testWidgets('says so when both lookups fail', (tester) async {
    final api = FakeGamesApi();
    api.onPrice = (_) async => throw const ApiException('down');
    api.onKeyShops = (_) async => throw const ApiException('down');

    await pumpSheet(tester, api);

    expect(find.text('No price data available.'), findsOneWidget);
  });

  testWidgets('lists the deals and offers cheapest first', (tester) async {
    final api = FakeGamesApi();
    api.onPrice = (_) async => prices([steam, gog]);
    api.onKeyShops = (_) async => [royal];

    await pumpSheet(tester, api);

    final tops = [
      for (final key in [
        'price-keyshop-RoyalCDKeys',
        'price-cheapshark-GOG',
        'price-cheapshark-Steam',
      ])
        tester.getTopLeft(find.byKey(Key(key))).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(find.textContaining(r'$10.00'), findsOneWidget);
    expect(find.textContaining('€8.00'), findsOneWidget);
    expect(find.textContaining('-35%'), findsOneWidget);
    expect(find.textContaining(r'$25.00'), findsNWidgets(2));
  });

  testWidgets('shows the sale banner and the all-time low', (tester) async {
    final api = FakeGamesApi()
      ..onPrice = (_) async => prices([steam, gog], onSale: true, ever: 7.99);

    await pumpSheet(tester, api);

    expect(find.byKey(const Key('sale-banner')), findsOneWidget);
    expect(find.text('ON SALE NOW -60%'), findsOneWidget);
    expect(find.textContaining('at GOG'), findsOneWidget);
    expect(find.byKey(const Key('all-time-low-banner')), findsOneWidget);
    expect(find.textContaining(r'$7.99'), findsOneWidget);
  });

  testWidgets('has no banners for a game that is not on sale', (tester) async {
    final api = FakeGamesApi()..onPrice = (_) async => prices([steam]);

    await pumpSheet(tester, api);

    expect(find.byKey(const Key('sale-banner')), findsNothing);
    expect(find.byKey(const Key('all-time-low-banner')), findsNothing);
  });

  testWidgets('a row opens its link in the browser', (tester) async {
    final api = FakeGamesApi()..onPrice = (_) async => prices([gog]);
    final opened = await pumpSheet(tester, api);

    await tester.tap(find.byKey(const Key('price-cheapshark-GOG')));
    await tester.pump();

    expect(opened, [Uri.parse('https://www.gog.com/game/1')]);
  });

  testWidgets('the Keyforsteam row opens a Google site search', (tester) async {
    final api = FakeGamesApi()..onPrice = (_) async => prices([gog]);
    final opened = await pumpSheet(tester, api, title: 'Hades II');

    await tester.tap(find.byKey(const Key('keyforsteam-row')));
    await tester.pump();

    expect(
      opened.single.toString(),
      'https://www.google.com/search?q=site%3Akeyforsteam.de+Hades+II',
    );
  });

  testWidgets('never opens a link that is not http or https', (tester) async {
    final api = FakeGamesApi()
      ..onPrice = (_) async => prices([
        const PriceDeal(
          store: 'Evil',
          iconUrl: '',
          price: 1,
          retailPrice: 2,
          url: 'javascript:alert(1)',
        ),
        gog,
      ]);
    await pumpSheet(tester, api);

    expect(find.byKey(const Key('price-cheapshark-Evil')), findsNothing);
    expect(find.byKey(const Key('price-cheapshark-GOG')), findsOneWidget);
  });

  testWidgets('a game without a Steam App ID only asks the key shops', (
    tester,
  ) async {
    final api = FakeGamesApi()..onKeyShops = (_) async => [royal];

    await pumpSheet(tester, api, steamAppId: null);

    expect(api.calls, ['keys Hades']);
    expect(find.byKey(const Key('price-keyshop-RoyalCDKeys')), findsOneWidget);
  });

  testWidgets('golden: the price sheet', tags: 'golden', (tester) async {
    final api = FakeGamesApi();
    api.onPrice = (_) async => prices([steam, gog], onSale: true, ever: 7.99);
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
