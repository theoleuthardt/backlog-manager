import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/data/game_info_providers.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/design/widgets/search_input.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/features/add_game/game_result_parts.dart';
import 'package:backlog_manager/features/common/debouncer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _searchDelay = Duration(milliseconds: 300);

/// Opens the SteamGridDB cover picker; the future is the address of the cover
/// the user chose, or null. Without a Steam App ID it starts with a search for
/// [initialQuery].
Future<String?> showCoverPicker(
  BuildContext context, {
  required String initialQuery,
  int? steamAppId,
}) {
  return showShelfSheet<String>(
    context,
    builder: (_) =>
        CoverPickerSheet(initialQuery: initialQuery, steamAppId: steamAppId),
  );
}

/// The covers SteamGridDB has for the Steam App ID of an entry, with a search
/// for another title; picking a search result shows the covers of that game.
class CoverPickerSheet extends ConsumerStatefulWidget {
  const CoverPickerSheet({
    required this.initialQuery,
    this.steamAppId,
    super.key,
  });

  final String initialQuery;
  final int? steamAppId;

  @override
  ConsumerState<CoverPickerSheet> createState() => _CoverPickerSheetState();
}

class _CoverPickerSheetState extends ConsumerState<CoverPickerSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.steamAppId == null ? widget.initialQuery : '',
  );
  final _debouncer = Debouncer(_searchDelay);
  late String _term = _controller.text.trim();
  int? _gameId;

  @override
  void dispose() {
    _debouncer.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _debouncer.run(() {
      if (mounted) setState(() => _term = text.trim());
    });
  }

  void _pick(SteamGridDbMatch match) {
    _controller.clear();
    setState(() {
      _gameId = match.id;
      _term = '';
    });
  }

  AsyncValue<List<String>>? get _covers {
    final gameId = _gameId;
    if (gameId != null) return ref.watch(steamGridDbCoversByIdProvider(gameId));
    final appId = widget.steamAppId;
    return appId == null ? null : ref.watch(steamGridDbCoversProvider(appId));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final search = _term.isEmpty
        ? null
        : ref.watch(steamGridDbSearchProvider(_term));
    final matches = search?.value ?? const <SteamGridDbMatch>[];
    final covers = _covers;

    final Widget body;
    if (_term.isNotEmpty && (search?.isLoading ?? false)) {
      body = const SheetNote(
        'Searching...',
        busy: true,
        noteKey: Key('cover-searching'),
      );
    } else if (_term.isNotEmpty && (search?.hasError ?? false)) {
      body = SheetNote(
        ApiException.from(search!.error!, 'SteamGridDB search failed').message,
        noteKey: const Key('cover-search-error'),
      );
    } else if (_term.isNotEmpty && matches.isEmpty) {
      body = SheetNote(
        'No game found for "$_term".',
        noteKey: const Key('cover-no-match'),
      );
    } else if (_term.isNotEmpty) {
      body = Column(
        key: const Key('cover-matches'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final match in matches)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ShelfPressable(
                onPressed: () => _pick(match),
                semanticLabel: match.name,
                borderRadius: 6,
                builder: (context, state) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: state.hovered ? tokens.glowSoft : null,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(match.name, style: style.control),
                  ),
                ),
              ),
            ),
        ],
      );
    } else if (covers == null) {
      body = const SheetNote(
        'No Steam App ID for this entry - search above to find covers for it on '
        'SteamGridDB.',
        noteKey: Key('cover-no-id'),
      );
    } else if (covers.isLoading) {
      body = const SheetNote(
        'Loading covers...',
        busy: true,
        noteKey: Key('cover-loading'),
      );
    } else if (covers.hasError) {
      body = SheetNote(
        ApiException.from(
          covers.error!,
          'Failed to load covers. Please try again.',
        ).message,
        noteKey: const Key('cover-error'),
      );
    } else if (covers.requireValue.isEmpty) {
      body = const SheetNote(
        'No SteamGridDB covers available for this game.',
        noteKey: Key('cover-empty'),
      );
    } else {
      body = Wrap(
        key: const Key('cover-grid'),
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final url in covers.requireValue)
            _CoverOption(
              url: url,
              onPressed: () => Navigator.of(context).pop(url),
            ),
        ],
      );
    }

    return ShelfSheet(
      title: 'SteamGridDB Covers',
      width: ShelfSheetWidth.wide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShelfSearchInput(
            controller: _controller,
            hintText: 'Search a different title on SteamGridDB...',
            autofocus: widget.steamAppId == null,
            onChanged: _typed,
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }
}

class _CoverOption extends ConsumerWidget {
  const _CoverOption({required this.url, required this.onPressed});

  final String url;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final image = entryImage(ref.watch(serverUrlProvider).value, url);
    return ShelfPressable(
      onPressed: onPressed,
      semanticLabel: 'Cover option',
      borderRadius: 6,
      builder: (context, state) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: state.hovered ? tokens.borderStrong : tokens.borderSubtle,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            width: 130,
            height: 195,
            child: image == null
                ? ColoredBox(color: tokens.surface3)
                : Image(
                    image: image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        ColoredBox(color: tokens.surface3),
                  ),
          ),
        ),
      ),
    );
  }
}
