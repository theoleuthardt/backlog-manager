import 'dart:async';

import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/note.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/design/widgets/search_input.dart';
import 'package:backlog_manager/design/widgets/segmented.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/domain/steam_sync.dart';
import 'package:backlog_manager/features/steam/steam_controller.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _gutter = 28.0;

/// The Steam screen: a preview of the games the Steam library or the wishlist
/// would add to the backlog, with check boxes, and an import of the checked
/// rows. Nothing is written until Import.
class SteamPage extends ConsumerStatefulWidget {
  const SteamPage({super.key});

  @override
  ConsumerState<SteamPage> createState() => _SteamPageState();
}

class _SteamPageState extends ConsumerState<SteamPage> {
  final _filter = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportStatus();
    });
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _reportStatus() {
    final source = ref.read(steamProvider).source;
    ref
        .read(shellStatusProvider.notifier)
        .update(
          counts: source == SteamSource.library
              ? 'Steam library · preview'
              : 'Steam wishlist · preview',
        );
  }

  void _show(SteamNotice? notice) {
    if (notice != null && mounted) showShelfToast(context, notice.message);
  }

  Future<void> _load() async =>
      _show(await ref.read(steamProvider.notifier).load());

  Future<void> _import() async {
    final notices = await ref.read(steamProvider.notifier).import();
    if (notices.isNotEmpty) {
      _show(SteamNotice(notices.map((notice) => notice.message).join('. ')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(steamProvider);
    final user = ref.watch(sessionUserProvider);
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final controller = ref.read(steamProvider.notifier);
    final linked = user?.hasSteamId ?? false;
    final importedOn = wishlistImportDate(user?.steamWishlistImportedAt);
    final wishlistImported = user?.steamWishlistImportedAt != null;
    final source = wishlistImported ? SteamSource.library : state.source;
    final previewing = state.phase == SteamPhase.previewing;
    final rows = state.rows;

    ref.listen(
      steamProvider.select((s) => s.source),
      (_, _) => _reportStatus(),
    );

    return Column(
      key: const Key('page-steam'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_gutter, 22, _gutter, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!wishlistImported)
                ShelfSegmented<SteamSource>(
                  segments: const [
                    ShelfSegment(value: SteamSource.library, label: 'Library'),
                    ShelfSegment(
                      value: SteamSource.wishlist,
                      label: 'Wishlist',
                    ),
                  ],
                  value: source,
                  onChanged: controller.setSource,
                )
              else
                Text('Steam library', style: style.page),
              ShelfButton(
                key: const Key('steam-load'),
                label: previewing
                    ? 'Loading...'
                    : rows == null
                    ? 'Load preview'
                    : 'Reload preview',
                kind: ShelfButtonKind.primary,
                busy: previewing,
                onPressed: !linked || state.busy
                    ? null
                    : () => unawaited(_load()),
              ),
              if (previewing && source == SteamSource.library)
                SizedBox(
                  width: 180,
                  child: ShelfProgressBar(
                    value: state.total == null || state.total == 0
                        ? 0
                        : (state.processed ?? 0) / state.total!,
                  ),
                ),
              if (previewing && source == SteamSource.library)
                Text(
                  checkedLine(state.processed, state.total),
                  key: const Key('steam-checked'),
                  style: style.caption.copyWith(color: tokens.muted),
                ),
              if (previewing && source == SteamSource.library)
                ShelfButton(
                  key: const Key('steam-cancel'),
                  label: 'Cancel',
                  kind: ShelfButtonKind.quiet,
                  onPressed: controller.cancel,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(_gutter, 4, _gutter, 8),
          child: const ShelfNote(
            text: 'Nothing is written until you press Import.',
          ),
        ),
        if (!linked)
          Padding(
            padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 8),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Link your Steam account in the settings to load your '
                    'games.',
                    key: const Key('steam-not-linked'),
                    style: style.caption.copyWith(color: tokens.muted),
                  ),
                ),
                const SizedBox(width: 10),
                ShelfButton(
                  key: const Key('steam-open-settings'),
                  label: 'Open settings',
                  onPressed: () =>
                      context.go('${AppRoutes.settings}?tab=integrations'),
                ),
              ],
            ),
          ),
        if (importedOn != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 8),
            child: ShelfNote(
              child: Text(
                'Your Steam wishlist was imported on $importedOn. The '
                'wishlist import is for the first time only; the games it '
                'created are marked as wishlist imports in your backlog. '
                'Automatic wishlist sync is '
                '${user?.steamWishlistAutoSync ?? false ? 'on' : 'off'}.',
                key: const Key('steam-wishlist-imported'),
                style: style.caption.copyWith(color: tokens.muted),
              ),
            ),
          ),
        Expanded(child: _body(state, source)),
        if (rows != null && rows.isNotEmpty)
          _Footer(state: state, onImport: () => unawaited(_import())),
      ],
    );
  }

  Widget _body(SteamState state, SteamSource source) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final controller = ref.read(steamProvider.notifier);
    final rows = state.rows;

    Widget message(String text, {Key? key}) => Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 6, _gutter, 0),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          text,
          key: key,
          style: style.body.copyWith(color: tokens.muted),
        ),
      ),
    );

    if (rows == null) {
      if (state.phase == SteamPhase.previewing) {
        return _LoadingPanel(source: source, state: state);
      }
      return message(
        'Nothing loaded yet - load a preview to see what would be imported.',
        key: const Key('steam-empty-hint'),
      );
    }
    if (rows.isEmpty) {
      return message(
        'Nothing new to import - your backlog already has everything.',
        key: const Key('steam-nothing-new'),
      );
    }
    final visible = state.visible;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 6, _gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        previewHeading(source, rows.length),
                        key: const Key('steam-heading'),
                        style: style.section,
                      ),
                    ),
                    ShelfButton(
                      key: const Key('steam-select-none'),
                      label: 'Select none',
                      kind: ShelfButtonKind.quiet,
                      onPressed: state.busy ? null : controller.selectNone,
                    ),
                    ShelfButton(
                      key: const Key('steam-select-all'),
                      label: 'Select all',
                      kind: ShelfButtonKind.quiet,
                      onPressed: state.busy ? null : controller.selectAll,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 240,
                child: ShelfSearchInput(
                  controller: _filter,
                  hintText: 'Filter list',
                  onChanged: controller.setQuery,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(ShelfRadius.card),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        'No games match the filter.',
                        key: const Key('steam-no-match'),
                        style: style.body.copyWith(color: tokens.muted),
                      ),
                    )
                  : ListView.builder(
                      key: const Key('steam-rows'),
                      itemCount: visible.length,
                      itemBuilder: (context, index) => _SteamRowTile(
                        key: ValueKey(visible[index].steamAppId),
                        row: visible[index],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SteamRowTile extends ConsumerWidget {
  const _SteamRowTile({required this.row, super.key});

  final SteamRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final selected = ref.watch(
      steamProvider.select((s) => s.selected.contains(row.steamAppId)),
    );
    final busy = ref.watch(steamProvider.select((s) => s.busy));
    final serverUrl = ref.watch(serverUrlProvider).value;
    final image = row.imageLink == null
        ? null
        : entryImage(serverUrl, row.imageLink!);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy
          ? null
          : () => ref.read(steamProvider.notifier).toggle(row.steamAppId),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoft : null,
          border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              ShelfCheckbox(
                key: Key('steam-check-${row.steamAppId}'),
                value: selected,
                label: row.title,
                onChanged: busy
                    ? null
                    : (_) => ref
                          .read(steamProvider.notifier)
                          .toggle(row.steamAppId),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 60,
                  height: 28,
                  child: image == null
                      ? ColoredBox(color: tokens.surface3)
                      : Image(image: image, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.label.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  '${row.steamAppId}',
                  style: style.caption.copyWith(color: tokens.faint),
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  steamHoursLabel(row.playtime),
                  textAlign: TextAlign.right,
                  style: style.caption.copyWith(color: tokens.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.state, required this.onImport});

  final SteamState state;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final rows = state.rows ?? const [];
    final selected = rows
        .where((row) => state.selected.contains(row.steamAppId))
        .length;
    final importing = state.phase == SteamPhase.importing;
    final total = state.total;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _gutter, vertical: 12),
        child: Row(
          children: [
            Text(
              selectedLabel(selected, rows.length),
              key: const Key('steam-selected'),
              style: style.body.copyWith(color: tokens.muted),
            ),
            if (importing && total != null) ...[
              const SizedBox(width: 16),
              SizedBox(
                width: 180,
                child: ShelfProgressBar(
                  value: total == 0 ? 0 : (state.processed ?? 0) / total,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${state.processed ?? 0}/$total',
                key: const Key('steam-import-progress'),
                style: style.caption.copyWith(color: tokens.muted),
              ),
              const SizedBox(width: 8),
              ShelfButton(
                key: const Key('steam-import-cancel'),
                label: 'Cancel',
                kind: ShelfButtonKind.quiet,
                onPressed: ref.read(steamProvider.notifier).cancel,
              ),
            ],
            const Spacer(),
            ShelfButton(
              key: const Key('steam-import'),
              label: importing ? 'Importing...' : steamImportLabel(selected),
              kind: ShelfButtonKind.primary,
              busy: importing,
              onPressed: state.busy || selected == 0 ? null : onImport,
            ),
          ],
        ),
      ),
    );
  }
}

/// What the page shows while a preview loads: which list is being read, a bar
/// (a sweeping one until the number of games is known) and how long it has
/// taken, so a big library does not look like a hung app.
class _LoadingPanel extends StatefulWidget {
  const _LoadingPanel({required this.source, required this.state});

  final SteamSource source;
  final SteamState state;

  @override
  State<_LoadingPanel> createState() => _LoadingPanelState();
}

class _LoadingPanelState extends State<_LoadingPanel>
    with SingleTickerProviderStateMixin {
  static const _limit = Duration(hours: 1);

  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: _limit,
  )..forward();

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final state = widget.state;
    final total = state.total;
    final library = widget.source == SteamSource.library;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_gutter, 48, _gutter, 0),
        child: ConstrainedBox(
          key: const Key('steam-loading'),
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                library
                    ? 'Reading your Steam library'
                    : 'Reading your Steam wishlist',
                style: style.section,
              ),
              const SizedBox(height: 6),
              Text(
                library
                    ? 'Every game is checked against your backlog and its '
                          'details are looked up, so a big library takes a '
                          'minute or two.'
                    : 'The wishlist and the details of its games are being '
                          'fetched.',
                style: style.body.copyWith(color: tokens.muted),
              ),
              const SizedBox(height: 22),
              if (total != null && total > 0)
                ShelfProgressBar(value: (state.processed ?? 0) / total)
              else
                const ShelfIndeterminateBar(),
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: _tick,
                builder: (context, _) {
                  final seconds = (_tick.value * _limit.inSeconds).floor();
                  final counted = total != null && total > 0
                      ? '${checkedLine(state.processed, total)} - '
                      : '';
                  return Text(
                    '$counted$seconds s',
                    key: const Key('steam-loading-time'),
                    style: style.caption.copyWith(color: tokens.faint),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
