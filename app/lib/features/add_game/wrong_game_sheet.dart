import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/game_info_providers.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/chips.dart';
import 'package:backlog_manager/design/widgets/search_input.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/table.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/features/add_game/game_result_parts.dart';
import 'package:backlog_manager/features/common/debouncer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _searchDelay = Duration(milliseconds: 300);

/// Opens "Find the right game" with the search prefilled with [initialQuery];
/// the future is the result the user chose, or null.
Future<GameSearchResult?> showWrongGameSheet(
  BuildContext context, {
  required String initialQuery,
}) {
  return showShelfSheet<GameSearchResult>(
    context,
    builder: (_) => WrongGameSheet(initialQuery: initialQuery),
  );
}

/// Searches for the game an entry really is. "Search more" asks for a deeper
/// search (other spellings, bundles) and marks what only it found.
class WrongGameSheet extends ConsumerStatefulWidget {
  const WrongGameSheet({required this.initialQuery, super.key});

  final String initialQuery;

  @override
  ConsumerState<WrongGameSheet> createState() => _WrongGameSheetState();
}

class _WrongGameSheetState extends ConsumerState<WrongGameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );
  final _debouncer = Debouncer(_searchDelay);
  late String _term = widget.initialQuery.trim();
  bool _deep = false;
  int? _selectedId;

  @override
  void dispose() {
    _debouncer.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _debouncer.run(() {
      if (!mounted) return;
      setState(() {
        if (text.trim() != _term) _deep = false;
        _term = text.trim();
        _selectedId = null;
      });
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final normal = _term.isEmpty
        ? null
        : ref.watch(gameSearchProvider((term: _term, deep: false)));
    final deep = _term.isEmpty || !_deep
        ? null
        : ref.watch(gameSearchProvider((term: _term, deep: true)));
    final active = _deep ? deep : normal;
    final results = active?.value ?? const <GameSearchResult>[];
    final deeper = _deep
        ? deeperIds(normal: normal?.value ?? const [], deep: results)
        : const <int>{};
    final loading =
        _controller.text.trim() != _term || (active?.isLoading ?? false);
    final selected = results.where((r) => r.id == _selectedId).firstOrNull;

    final Widget list;
    if (_term.isEmpty) {
      list = const SizedBox.shrink();
    } else if (loading) {
      list = const SheetNote(
        'Searching for game...',
        busy: true,
        noteKey: Key('wrong-searching'),
      );
    } else if (active?.hasError ?? false) {
      list = SheetNote(
        ApiException.from(active!.error!, 'Game search failed').message,
        noteKey: const Key('wrong-error'),
      );
    } else if (results.isEmpty) {
      list = const SheetNote('No results found.', noteKey: Key('wrong-empty'));
    } else {
      list = ShelfDataTable<GameSearchResult>(
        columns: [
          ShelfColumn(
            header: 'Game',
            flex: 1,
            cell: (context, result) => Row(
              children: [
                ResultThumb(imageUrl: result.imageUrl, width: 26, height: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        overflow: TextOverflow.ellipsis,
                        style: style.control.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        result.hoursLine,
                        overflow: TextOverflow.ellipsis,
                        style: style.caption.copyWith(color: tokens.faint),
                      ),
                    ],
                  ),
                ),
                if (deeper.contains(result.id))
                  const ShelfChip(
                    key: Key('deeper-marker'),
                    label: 'Found by deeper search',
                  ),
              ],
            ),
          ),
        ],
        rows: results,
        isSelected: (result) => result.id == _selectedId,
        onRowTap: (result) => setState(() => _selectedId = result.id),
      );
    }

    return ShelfSheet(
      title: 'Find the right game',
      width: ShelfSheetWidth.standard,
      footer: ShelfSheetFooter(
        onCancel: () => Navigator.of(context).pop(),
        primary: ShelfButton(
          key: const Key('wrong-use'),
          label: 'Use this game',
          kind: ShelfButtonKind.primary,
          onPressed: selected == null
              ? null
              : () => Navigator.of(context).pop(selected),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShelfSearchInput(
            controller: _controller,
            hintText: 'Search game...',
            autofocus: true,
            onChanged: _typed,
          ),
          const SizedBox(height: 10),
          list,
          if (_term.isNotEmpty && !_deep && !loading) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Searching deeper also tries other spellings and bundles.',
                    style: style.caption.copyWith(color: tokens.muted),
                  ),
                ),
                const SizedBox(width: 10),
                ShelfButton(
                  key: const Key('wrong-search-more'),
                  label: "Can't find your game? Search more",
                  onPressed: () => setState(() {
                    _deep = true;
                    _selectedId = null;
                  }),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
