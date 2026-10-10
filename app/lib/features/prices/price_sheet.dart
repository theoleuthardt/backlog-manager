import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/data/game_info_providers.dart';
import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/domain/price_listings.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the price sheet of a game: the CheapShark deals (when it has a Steam
/// App ID) and the key shop offers in one list, only loaded while the sheet
/// is open.
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
    final listings = buildListings(info, offers?.value);

    return ShelfSheet(
      title: 'Price',
      description: title,
      width: ShelfSheetWidth.compact,
      child: loading
          ? const _Loading()
          : listings.isEmpty
          ? const _Message('No price data available.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (saleBanner(info) case final banner?)
                  _SaleBanner(banner: banner),
                if (info?.cheapestPriceEver case final low?)
                  _AllTimeLow(price: low),
                _KeyforsteamRow(title: title),
                for (final listing in listings) _ListingRow(listing: listing),
              ],
            ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Row(
      key: const Key('price-loading'),
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: tokens.accent,
          ),
        ),
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

class _SaleBanner extends StatelessWidget {
  const _SaleBanner({required this.banner});

  final SaleBanner banner;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final discount = banner.discountPercent;
    return _Banner(
      bannerKey: const Key('sale-banner'),
      color: tokens.success,
      icon: Icons.local_fire_department_outlined,
      label: 'On Sale Now${discount > 0 ? ' -$discount%' : ''}',
      value: formatMoney('USD', banner.price),
      suffix: 'at ${banner.store}',
    );
  }
}

class _AllTimeLow extends StatelessWidget {
  const _AllTimeLow({required this.price});

  final double price;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return _Banner(
      bannerKey: const Key('all-time-low-banner'),
      color: tokens.accent,
      icon: Icons.trending_down,
      label: 'All-Time Low',
      value: formatMoney('USD', price),
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
    final query = Uri.encodeQueryComponent('site:keyforsteam.de $title');
    return _RowShell(
      rowKey: const Key('keyforsteam-row'),
      url: 'https://www.google.com/search?q=$query',
      leading: Icon(Icons.search, size: 20, color: tokens.muted),
      name: 'Keyforsteam',
      trailing: Text(
        'Compare prices',
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
    final crossedOut = listing.crossedOutPrice;
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
            if (crossedOut != null)
              TextSpan(
                text: ' ${formatMoney(listing.currency, crossedOut)}',
                style: style.caption.copyWith(
                  color: tokens.faint,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
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

class _StoreIcon extends ConsumerWidget {
  const _StoreIcon({required this.listing});

  final PriceListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface3,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    final local = listing.localIcon;
    final remote = listing.iconUrl;
    final image = local != null
        ? AssetImage(local)
        : remote == null
        ? null
        : entryImage(ref.watch(serverUrlProvider).value, remote);
    return SizedBox(
      width: 20,
      height: 20,
      child: image == null
          ? placeholder
          : Image(
              image: image,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
