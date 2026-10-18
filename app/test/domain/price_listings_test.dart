import 'package:backlog_manager/domain/price_listings.dart';
import 'package:flutter_test/flutter_test.dart';

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

PriceInfo info({
  double? retail,
  double? keyshops,
  double? historicalRetail,
  double? historicalKeyshops,
}) => PriceInfo(
  currency: 'EUR',
  currentRetail: retail,
  currentKeyshops: keyshops,
  historicalRetail: historicalRetail,
  historicalKeyshops: historicalKeyshops,
  url: 'https://gg.deals/game/hades/',
);

void main() {
  group('PriceInfo.hasPrices', () {
    test('is true with any of the four prices', () {
      expect(info(retail: 1).hasPrices, isTrue);
      expect(info(keyshops: 1).hasPrices, isTrue);
      expect(info(historicalRetail: 1).hasPrices, isTrue);
      expect(info(historicalKeyshops: 1).hasPrices, isTrue);
    });

    test('is false for a game GG.deals has no prices for', () {
      expect(info().hasPrices, isFalse);
    });
  });

  group('lowestEver', () {
    test('is the official store price when it is at its lowest', () {
      final low = lowestEver(
        info(
          retail: 2,
          historicalRetail: 2,
          keyshops: 5,
          historicalKeyshops: 1,
        ),
      )!;

      expect(low.channel, PriceChannel.officialStore);
      expect(low.price, 2);
    });

    test('is the keyshop price when it is at its lowest', () {
      final low = lowestEver(
        info(
          retail: 9,
          historicalRetail: 2,
          keyshops: 1,
          historicalKeyshops: 1,
        ),
      )!;

      expect(low.channel, PriceChannel.keyshop);
      expect(low.price, 1);
    });

    test('is the cheaper one when both are at their lowest', () {
      final low = lowestEver(
        info(
          retail: 3,
          historicalRetail: 3,
          keyshops: 2,
          historicalKeyshops: 2,
        ),
      )!;

      expect(low.channel, PriceChannel.keyshop);
    });

    test('is absent while neither is at its lowest or the data is missing', () {
      expect(
        lowestEver(info(retail: 9, historicalRetail: 2, keyshops: 5)),
        isNull,
      );
      expect(lowestEver(info(retail: 2)), isNull);
      expect(lowestEver(info()), isNull);
      expect(lowestEver(null), isNull);
    });

    test('is never a price of zero', () {
      expect(lowestEver(info(retail: 0, historicalRetail: 0)), isNull);
    });
  });

  group('buildListings', () {
    test('sorts the key shop offers by the price in euro', () {
      final listings = buildListings([
        offer('PremiumCDKeys', 9.5),
        offer('RoyalCDKeys', 7.5),
      ]);

      expect(listings.map((l) => l.store), ['RoyalCDKeys', 'PremiumCDKeys']);
    });

    test('converts a dollar price with the factor 0.9', () {
      final listings = buildListings([
        offer('A', 10, currency: 'USD'),
        offer('B', 9.5),
      ]);

      expect(listings.map((l) => l.store), ['A', 'B']);
      expect(listings.first.priceInEuro, closeTo(9, 0.0001));
    });

    test('sorts an offer in an unknown currency after the known ones', () {
      final listings = buildListings([
        offer('Odd', 1, currency: 'GBP'),
        offer('Euro', 100),
      ]);

      expect(listings.map((l) => l.store), ['Euro', 'Odd']);
    });

    test('leaves out links that are not http or https', () {
      final listings = buildListings([
        offer('Bad', 1, url: 'file:///etc/passwd'),
        offer('Fine', 2),
      ]);

      expect(listings.map((l) => l.store), ['Fine']);
    });

    test('shows the local icon of a known key shop only', () {
      final listings = buildListings([
        offer('RoyalCDKeys', 5),
        offer('Unknown', 6),
      ]);

      expect(listings[0].localIcon, 'assets/royalcdkeys-icon.png');
      expect(listings[1].localIcon, isNull);
    });

    test('shows the discount only when it is positive', () {
      final listings = buildListings([
        offer('A', 5, discount: 30),
        offer('B', 6, discount: 0),
        offer('C', 7),
      ]);

      expect(listings.map((l) => l.discountPct), [30, null, null]);
    });

    test('is empty without offers', () {
      expect(buildListings(null), isEmpty);
      expect(buildListings(const []), isEmpty);
    });
  });

  group('formatMoney', () {
    test('writes the symbol of a known currency before two decimals', () {
      expect(formatMoney('USD', 9.5), r'$9.50');
      expect(formatMoney('EUR', 12), '€12.00');
    });

    test('puts the code of an unknown currency after the amount', () {
      expect(formatMoney('PLN', 3.456), '3.46 PLN');
    });

    test('writes just the amount without a currency', () {
      expect(formatMoney(null, 3), '3.00');
    });
  });
}
