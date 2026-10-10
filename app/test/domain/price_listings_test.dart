import 'package:backlog_manager/domain/price_listings.dart';
import 'package:flutter_test/flutter_test.dart';

PriceDeal deal(
  String store,
  double price, {
  double retail = 20,
  String url = 'https://store.example/deal',
}) => PriceDeal(
  store: store,
  iconUrl: '/icons/$store.png',
  price: price,
  retailPrice: retail,
  url: url,
);

KeyShopOffer offer(
  String shop,
  double price, {
  String currency = 'EUR',
  int? discount,
  String url = 'https://keys.example/offer',
}) => KeyShopOffer(
  shop: shop,
  title: 'Hades',
  price: price,
  currency: currency,
  url: url,
  discountPct: discount,
);

PriceInfo info(List<PriceDeal> deals, {bool onSale = false, double? ever}) =>
    PriceInfo(deals: deals, onSale: onSale, cheapestPriceEver: ever);

void main() {
  group('buildListings', () {
    test('merges both sources sorted by the price in euro', () {
      final listings = buildListings(
        info([deal('Steam', 10), deal('GOG', 8)]),
        [offer('RoyalCDKeys', 7.5), offer('PremiumCDKeys', 9.5)],
      );

      expect(listings.map((l) => l.store), [
        'GOG',
        'RoyalCDKeys',
        'Steam',
        'PremiumCDKeys',
      ]);
    });

    test('converts a dollar price with the factor 0.9', () {
      final listings = buildListings(info([deal('Steam', 10)]), [
        offer('RoyalCDKeys', 9.5),
      ]);

      expect(listings.map((l) => l.store), ['Steam', 'RoyalCDKeys']);
      expect(listings.first.priceInEuro, closeTo(9, 0.0001));
    });

    test('sorts an offer in an unknown currency after the known ones', () {
      final listings = buildListings(info([deal('Steam', 100)]), [
        offer('Odd', 1, currency: 'GBP'),
      ]);

      expect(listings.map((l) => l.store), ['Steam', 'Odd']);
    });

    test('knows the currency of each source', () {
      final listings = buildListings(info([deal('Steam', 10)]), [
        offer('RoyalCDKeys', 12),
      ]);

      expect(listings.firstWhere((l) => l.store == 'Steam').currency, 'USD');
      expect(
        listings.firstWhere((l) => l.store == 'RoyalCDKeys').currency,
        'EUR',
      );
    });

    test('leaves out links that are not http or https', () {
      final listings = buildListings(
        info([deal('Evil', 1, url: 'javascript:alert(1)'), deal('Fine', 2)]),
        [offer('Bad', 1, url: 'file:///etc/passwd')],
      );

      expect(listings.map((l) => l.store), ['Fine']);
    });

    test('shows the local icon of a known key shop only', () {
      final listings = buildListings(null, [
        offer('RoyalCDKeys', 5),
        offer('Unknown', 6),
      ]);

      expect(listings[0].localIcon, 'assets/royalcdkeys-icon.png');
      expect(listings[1].localIcon, isNull);
      expect(listings[1].iconUrl, isNull);
    });

    test('uses the icon address of a CheapShark deal', () {
      final listings = buildListings(info([deal('Steam', 10)]), null);

      expect(listings.single.iconUrl, '/icons/Steam.png');
      expect(listings.single.localIcon, isNull);
    });

    test('is empty without any data', () {
      expect(buildListings(null, null), isEmpty);
      expect(buildListings(info(const []), const []), isEmpty);
    });
  });

  group('formatMoney', () {
    test('writes the symbol of a known currency before two decimals', () {
      expect(formatMoney('USD', 9.5), r'$9.50');
      expect(formatMoney('EUR', 12), '€12.00');
    });

    test('falls back to the currency code', () {
      expect(formatMoney('GBP', 3.456), 'GBP3.46');
    });
  });

  group('the listing price details', () {
    test('crosses out a retail price above the price', () {
      final listing = buildListings(
        info([deal('Steam', 10, retail: 20)]),
        null,
      ).single;
      expect(listing.crossedOutPrice, 20);
    });

    test('has no crossed-out price when the retail price is not higher', () {
      final listing = buildListings(
        info([deal('Steam', 10, retail: 10)]),
        null,
      ).single;
      expect(listing.crossedOutPrice, isNull);
    });

    test('shows the discount of a key shop offer only when it is positive', () {
      final listings = buildListings(null, [
        offer('A', 5, discount: 30),
        offer('B', 6, discount: 0),
        offer('C', 7),
      ]);
      expect(listings.map((l) => l.discountPct), [30, null, null]);
    });
  });

  group('saleBanner', () {
    test('is the cheapest deal with its rounded discount', () {
      final banner = saleBanner(
        info([deal('Steam', 15), deal('GOG', 7.5, retail: 30)], onSale: true),
      )!;

      expect(banner.store, 'GOG');
      expect(banner.price, 7.5);
      expect(banner.discountPercent, 75);
    });

    test('is absent when the game is not on sale', () {
      expect(saleBanner(info([deal('Steam', 10)])), isNull);
      expect(saleBanner(null), isNull);
      expect(saleBanner(info(const [], onSale: true)), isNull);
    });

    test('has no discount for a deal that is not below the retail price', () {
      final banner = saleBanner(
        info([deal('Steam', 10, retail: 10)], onSale: true),
      )!;
      expect(banner.discountPercent, 0);
    });
  });
}
