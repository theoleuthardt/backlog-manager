import 'package:backlog_manager/domain/safe_url.dart';

/// The GG.deals prices of a Steam game in one [currency]: the lowest price
/// now and the lowest ever, in the official stores and in keyshops. A price
/// GG.deals does not have is null. [url] is the page of the game on GG.deals,
/// which has to be linked as it is.
class PriceInfo {
  const PriceInfo({
    this.currency,
    this.currentRetail,
    this.currentKeyshops,
    this.historicalRetail,
    this.historicalKeyshops,
    this.url,
  });

  final String? currency;
  final double? currentRetail;
  final double? currentKeyshops;
  final double? historicalRetail;
  final double? historicalKeyshops;
  final String? url;

  bool get hasPrices =>
      currentRetail != null ||
      currentKeyshops != null ||
      historicalRetail != null ||
      historicalKeyshops != null;
}

/// Where a price is from.
enum PriceChannel { officialStore, keyshop }

/// A current price that is the lowest the game ever had.
class LowestEver {
  const LowestEver({required this.channel, required this.price});

  final PriceChannel channel;
  final double price;
}

/// The cheaper of the current prices that equal their lowest ever, or null
/// when none does. A price of zero never counts.
LowestEver? lowestEver(PriceInfo? info) {
  if (info == null) return null;
  final candidates = [
    for (final (current, historical, channel) in [
      (info.currentRetail, info.historicalRetail, PriceChannel.officialStore),
      (info.currentKeyshops, info.historicalKeyshops, PriceChannel.keyshop),
    ])
      if (current != null &&
          historical != null &&
          current > 0 &&
          current <= historical)
        LowestEver(channel: channel, price: current),
  ];
  if (candidates.isEmpty) return null;
  return candidates.reduce((a, b) => b.price < a.price ? b : a);
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

/// One row of the key shop list.
class PriceListing {
  const PriceListing({
    required this.key,
    required this.store,
    required this.price,
    required this.currency,
    required this.url,
    this.localIcon,
    this.discountPct,
  });

  final String key;
  final String store;
  final double price;
  final String currency;
  final String url;

  /// An icon that ships with the app, for the key shops.
  final String? localIcon;

  /// The discount of a key shop offer, when it is positive.
  final int? discountPct;

  /// The price in euro; infinite for a currency without a known rate, so such
  /// an offer sorts after the others.
  double get priceInEuro {
    final rate = _eurPerUnit[currency];
    return rate == null ? double.infinity : price * rate;
  }
}

const _eurPerUnit = {'USD': 0.9, 'EUR': 1.0};

const _currencySymbols = {'USD': r'$', 'EUR': '€'};

const _keyShopIcons = {
  'RoyalCDKeys': 'assets/royalcdkeys-icon.png',
  'PremiumCDKeys': 'assets/premiumcdkeys-icon.png',
};

/// "$9.50" or "€12.00"; an unknown currency follows the amount ("3.46 PLN"),
/// no currency leaves just the amount.
String formatMoney(String? currency, double amount) {
  final text = amount.toStringAsFixed(2);
  if (currency == null) return text;
  final symbol = _currencySymbols[currency];
  return symbol == null ? '$text $currency' : '$symbol$text';
}

/// The key shop offers as a list, cheapest first by the price in euro (a
/// dollar is 0.9 euro). Only http and https links are kept.
List<PriceListing> buildListings(List<KeyShopOffer>? offers) {
  final listings = [
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
