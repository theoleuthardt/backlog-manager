import 'package:backlog_manager/domain/safe_url.dart';

/// One CheapShark deal, in US dollars.
class PriceDeal {
  const PriceDeal({
    required this.store,
    required this.iconUrl,
    required this.price,
    required this.retailPrice,
    required this.url,
  });

  final String store;
  final String iconUrl;
  final double price;
  final double retailPrice;
  final String url;
}

/// The CheapShark prices of a Steam game.
class PriceInfo {
  const PriceInfo({
    required this.deals,
    required this.onSale,
    this.cheapestPriceEver,
  });

  final List<PriceDeal> deals;
  final bool onSale;

  /// The lowest price in dollars the game ever had, when CheapShark knows it.
  final double? cheapestPriceEver;
}

/// One offer of a key shop, in its own currency.
class KeyShopOffer {
  const KeyShopOffer({
    required this.shop,
    required this.title,
    required this.price,
    required this.currency,
    required this.url,
    this.discountPct,
  });

  final String shop;
  final String title;
  final double price;
  final String currency;
  final String url;
  final int? discountPct;
}

/// One row of the price list, whichever source it came from.
class PriceListing {
  const PriceListing({
    required this.key,
    required this.store,
    required this.price,
    required this.currency,
    required this.url,
    this.iconUrl,
    this.localIcon,
    this.crossedOutPrice,
    this.discountPct,
  });

  final String key;
  final String store;
  final double price;
  final String currency;
  final String url;

  /// A store icon to load through the image proxy.
  final String? iconUrl;

  /// An icon that ships with the app, for the key shops.
  final String? localIcon;

  /// The retail price, when it is above [price].
  final double? crossedOutPrice;

  /// The discount of a key shop offer, when it is positive.
  final int? discountPct;

  /// The price in euro; infinite for a currency without a known rate, so such
  /// an offer sorts after the others.
  double get priceInEuro {
    final rate = _eurPerUnit[currency];
    return rate == null ? double.infinity : price * rate;
  }
}

/// The cheapest CheapShark deal of a game that is on sale.
class SaleBanner {
  const SaleBanner({
    required this.store,
    required this.price,
    required this.discountPercent,
  });

  final String store;
  final double price;

  /// The discount against the retail price in whole percent, 0 when the deal
  /// is not below it.
  final int discountPercent;
}

const _eurPerUnit = {'USD': 0.9, 'EUR': 1.0};

const _currencySymbols = {'USD': r'$', 'EUR': '€'};

const _keyShopIcons = {
  'RoyalCDKeys': 'assets/royalcdkeys-icon.png',
  'PremiumCDKeys': 'assets/premiumcdkeys-icon.png',
};

/// "$9.50" or "€12.00"; an unknown currency is written as its code.
String formatMoney(String currency, double amount) {
  return '${_currencySymbols[currency] ?? currency}${amount.toStringAsFixed(2)}';
}

/// The CheapShark deals and the key shop offers as one list, cheapest first
/// by the price in euro (a dollar is 0.9 euro). Only http and https links are
/// kept.
List<PriceListing> buildListings(PriceInfo? info, List<KeyShopOffer>? offers) {
  final listings = [
    for (final deal in info?.deals ?? const <PriceDeal>[])
      if (isHttpUrl(deal.url))
        PriceListing(
          key: 'cheapshark-${deal.store}',
          store: deal.store,
          iconUrl: deal.iconUrl,
          price: deal.price,
          currency: 'USD',
          crossedOutPrice: deal.retailPrice > deal.price
              ? deal.retailPrice
              : null,
          url: deal.url,
        ),
    for (final offer in offers ?? const <KeyShopOffer>[])
      if (isHttpUrl(offer.url))
        PriceListing(
          key: 'keyshop-${offer.shop}',
          store: offer.shop,
          localIcon: _keyShopIcons[offer.shop],
          price: offer.price,
          currency: offer.currency,
          discountPct: (offer.discountPct ?? 0) > 0 ? offer.discountPct : null,
          url: offer.url,
        ),
  ];
  listings.sort((a, b) => a.priceInEuro.compareTo(b.priceInEuro));
  return listings;
}

/// The "On Sale Now" banner, or null when the game is not on sale.
SaleBanner? saleBanner(PriceInfo? info) {
  if (info == null || !info.onSale || info.deals.isEmpty) return null;
  final cheapest = info.deals.reduce(
    (lowest, deal) => deal.price < lowest.price ? deal : lowest,
  );
  final discount = cheapest.retailPrice > cheapest.price
      ? ((1 - cheapest.price / cheapest.retailPrice) * 100).round()
      : 0;
  return SaleBanner(
    store: cheapest.store,
    price: cheapest.price,
    discountPercent: discount,
  );
}
