import 'package:backlog_manager/data/game_info_providers.dart';
import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/spinner.dart';
import 'package:backlog_manager/domain/price_listings.dart';
import 'package:backlog_manager/domain/safe_url.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the price sheet of a game: the GG.deals prices (when it has a Steam
/// App ID) kept apart as official stores and keyshops, the offers of the key
/// shops, and a search link, only loaded while the sheet is open.
Future<void> showPriceSheet(
  BuildContext context, {
  required String title,
  int? steamAppId,
}) {
  return showShelfSheet<void>(
    context,
    builder: (_) => PriceSheet(title: title, steamAppId: steamAppId),
  );
}

class PriceSheet extends ConsumerWidget {
  const PriceSheet({required this.title, this.steamAppId, super.key});

  final String title;
  final int? steamAppId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appId = steamAppId;
    final price = appId == null ? null : ref.watch(gamePriceProvider(appId));
    final offers = title.isEmpty
        ? null
        : ref.watch(keyShopPricesProvider(title));
    final loading = (price?.isLoading ?? false) || (offers?.isLoading ?? false);
    final info = price?.value;
    final hasPrices = info != null && info.hasPrices;
    final listings = buildListings(offers?.value);
    final currency = info?.currency;
    final link = info?.url ?? '';

    return ShelfSheet(
      title: 'Price',
      description: title,
      width: ShelfSheetWidth.compact,
      child: loading
          ? const _Loading()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lowestEver(info) case final low?)
                  _LowestEverBanner(low: low, currency: currency),
                if (!hasPrices && listings.isEmpty)
                  const _Message('No price data available.'),
                if (info != null &&
                    (info.currentRetail != null ||
                        info.historicalRetail != null)) ...[
                  const _SectionLabel(
                    'Official stores',
                    key: Key('price-section-official'),
                  ),
                  if (info.currentRetail case final now?)
                    _PriceRow(
                      rowKey: 'price-official-now',
                      label: 'Lowest now',
                      currency: currency,
                      amount: now,
                      url: link,
                    ),
                  if (info.historicalRetail case final ever?)
                    _PriceRow(
                      rowKey: 'price-official-ever',
                      label: 'Lowest ever',
                      currency: currency,
                      amount: ever,
                      url: link,
                    ),
                ],
                if (info != null &&
                        (info.currentKeyshops != null ||
                            info.historicalKeyshops != null) ||
                    listings.isNotEmpty) ...[
                  const _SectionLabel(
                    'Keyshops',
                    key: Key('price-section-keyshops'),
                  ),
                  if (info?.currentKeyshops case final now?)
                    _PriceRow(
                      rowKey: 'price-keyshops-now',
                      label: 'Lowest now',
                      currency: currency,
                      amount: now,
                      url: link,
                    ),
                  if (info?.historicalKeyshops case final ever?)
                    _PriceRow(
                      rowKey: 'price-keyshops-ever',
                      label: 'Lowest ever',
                      currency: currency,
                      amount: ever,
                      url: link,
                    ),
                  for (final listing in listings) _ListingRow(listing: listing),
                ],
                _KeyforsteamRow(title: title),
                if (hasPrices) _Attribution(url: link),
              ],
            ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Row(
      key: const Key('price-loading'),
      children: [
        const ShelfSpinner(size: 22),
        const SizedBox(width: 10),
        Text('Loading price...', style: style.caption),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Text(
      text,
      key: const Key('price-empty'),
      style: style.caption.copyWith(color: tokens.muted),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.bannerKey,
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    this.suffix,
  });

  final Key bannerKey;
  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        key: bannerKey,
        decoration: BoxDecoration(
          color: atOpacity(color, 0.12),
          borderRadius: BorderRadius.circular(ShelfRadius.control),
          border: Border.all(color: atOpacity(color, 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: style.keyHint.copyWith(color: color),
                    ),
                    Text.rich(
                      TextSpan(
                        text: value,
                        style: style.section.copyWith(color: color),
                        children: [
                          if (suffix != null)
                            TextSpan(
                              text: ' $suffix',
                              style: style.caption.copyWith(
                                color: atOpacity(color, 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LowestEverBanner extends StatelessWidget {
  const _LowestEverBanner({required this.low, required this.currency});

  final LowestEver low;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return _Banner(
      bannerKey: const Key('lowest-ever-banner'),
      color: tokens.success,
      icon: Icons.local_fire_department_outlined,
      label: 'Lowest price ever',
      value: formatMoney(currency, low.price),
      suffix: low.channel == PriceChannel.keyshop
          ? 'in keyshops'
          : 'in the official stores',
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: style.keyHint.copyWith(color: tokens.muted),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.rowKey,
    required this.label,
    required this.currency,
    required this.amount,
    required this.url,
  });

  final String rowKey;
  final String label;
  final String? currency;
  final double amount;
  final String url;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return _RowShell(
      rowKey: Key(rowKey),
      url: url,
      leading: Icon(Icons.sell_outlined, size: 20, color: tokens.muted),
      name: label,
      trailing: Text(formatMoney(currency, amount), style: style.control),
    );
  }
}

class _Attribution extends ConsumerWidget {
  const _Attribution({required this.url});

  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final target = Uri.parse(isHttpUrl(url) ? url : 'https://gg.deals');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          key: const Key('gg-deals-attribution'),
          onTap: () => ref.read(urlOpenerProvider)(target),
          child: Text(
            'Prices by GG.deals',
            style: style.caption.copyWith(
              color: tokens.accent,
              decoration: TextDecoration.underline,
              decorationColor: tokens.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _RowShell extends ConsumerWidget {
  const _RowShell({
    required this.rowKey,
    required this.url,
    required this.leading,
    required this.name,
    required this.trailing,
  });

  final Key rowKey;
  final String url;
  final Widget leading;
  final String name;
  final Widget trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ShelfPressable(
        borderRadius: ShelfRadius.control,
        semanticLabel: name,
        onPressed: () {
          final uri = Uri.tryParse(url);
          if (uri != null && isHttpUrl(url)) {
            ref.read(urlOpenerProvider)(uri);
          }
        },
        builder: (context, state) => DecoratedBox(
          key: rowKey,
          decoration: BoxDecoration(
            color: state.hovered ? tokens.glowSoft : null,
            borderRadius: BorderRadius.circular(ShelfRadius.control),
            border: Border.all(
              color: state.hovered ? tokens.borderStrong : tokens.borderSubtle,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: style.control,
                  ),
                ),
                trailing,
                const SizedBox(width: 8),
                Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: state.hovered ? tokens.muted : tokens.faint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyforsteamRow extends StatelessWidget {
  const _KeyforsteamRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return _RowShell(
      rowKey: const Key('keyforsteam-row'),
      url: keyforsteamSearchUrl(title),
      leading: Icon(Icons.search, size: 20, color: tokens.muted),
      name: 'Keyforsteam',
      trailing: Text(
        'Compare Prices',
        style: style.caption.copyWith(color: tokens.muted),
      ),
    );
  }
}

class _ListingRow extends ConsumerWidget {
  const _ListingRow({required this.listing});

  final PriceListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final discount = listing.discountPct;
    return _RowShell(
      rowKey: Key('price-${listing.key}'),
      url: listing.url,
      leading: _StoreIcon(listing: listing),
      name: listing.store,
      trailing: Text.rich(
        TextSpan(
          text: formatMoney(listing.currency, listing.price),
          style: style.control,
          children: [
            if (discount != null)
              TextSpan(
                text: ' -$discount%',
                style: style.caption.copyWith(color: tokens.success),
              ),
          ],
        ),
      ),
    );
  }
}

class _StoreIcon extends StatelessWidget {
  const _StoreIcon({required this.listing});

  final PriceListing listing;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface3,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    final local = listing.localIcon;
    return SizedBox(
      width: 20,
      height: 20,
      child: local == null
          ? placeholder
          : Image(
              image: AssetImage(local),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
