import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/game_info_providers.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/search_input.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/table.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/features/add_game/game_result_parts.dart';
import 'package:backlog_manager/features/common/debouncer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _searchDelay = Duration(milliseconds: 800);

/// Opens the "Search for a game" sheet. Inside a shared space [inSpace] makes
/// the shared space the target of the creation tool.
Future<void> showAddGameSheet(BuildContext context, {bool inSpace = false}) {
  return showShelfSheet<void>(
    context,
    builder: (_) => AddGameSheet(inSpace: inSpace),
  );
}

/// Searches games and carries the chosen one on to the creation tool; a game
/// the search does not know can be created as a custom game.
class AddGameSheet extends ConsumerStatefulWidget {
  const AddGameSheet({this.inSpace = false, super.key});

  final bool inSpace;

  @override
  ConsumerState<AddGameSheet> createState() => _AddGameSheetState();
}

class _AddGameSheetState extends ConsumerState<AddGameSheet> {
  final _controller = TextEditingController();
  final _debouncer = Debouncer(_searchDelay);
  String _term = '';
  int? _selectedId;

  @override
  void dispose() {
    _debouncer.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _settling => _controller.text.trim() != _term;

  void _typed(String text) {
    setState(() => _selectedId = null);
    _debouncer.run(() {
      if (mounted) setState(() => _term = text.trim());
    });
    setState(() {});
  }

  List<GameSearchResult> get _results {
    return ref.read(gameSearchProvider((term: _term, deep: false))).value ??
        const [];
  }

  GameSearchResult? get _selected =>
      _results.where((result) => result.id == _selectedId).firstOrNull;

  void _go(String location) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(location);
  }

  void _continue() {
    if (_settling) return;
    final chosen = _selected ?? _results.firstOrNull;
    if (chosen == null) return;
    _go(creationToolLocation(chosen, inSpace: widget.inSpace));
  }

  void _custom() {
    _go(customGameLocation(_controller.text.trim(), inSpace: widget.inSpace));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final search = _term.isEmpty
        ? null
        : ref.watch(gameSearchProvider((term: _term, deep: false)));
    final results = search?.value ?? const <GameSearchResult>[];

    final Widget content;
    if (_controller.text.trim().isEmpty) {
      content = const SizedBox.shrink();
    } else if (_settling || (search?.isLoading ?? false)) {
      content = const SheetNote(
        'Searching for game...',
        busy: true,
        noteKey: Key('add-searching'),
      );
    } else if (search?.hasError ?? false) {
      content = SheetNote(
        ApiException.from(search!.error!, 'Game search failed').message,
        noteKey: const Key('add-error'),
      );
    } else if (results.isEmpty) {
      content = Column(
        children: [
          const SheetNote('No results found', noteKey: Key('add-empty')),
          ShelfButton(
            key: const Key('add-custom-empty'),
            label: 'Create "$_term" as custom game',
            kind: ShelfButtonKind.primary,
            onPressed: _custom,
          ),
          const SizedBox(height: 8),
        ],
      );
    } else {
      content = ShelfDataTable<GameSearchResult>(
        columns: [
          ShelfColumn(
            header: 'Game',
            flex: 5,
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
                      if (result.platforms.isNotEmpty)
                        Text(
                          result.platforms.join(', '),
                          overflow: TextOverflow.ellipsis,
                          style: style.caption.copyWith(color: tokens.faint),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ShelfColumn(
            header: 'Genre',
            flex: 3,
            cell: (context, result) => Text(
              result.genres.join(', '),
              overflow: TextOverflow.ellipsis,
              style: style.caption.copyWith(color: tokens.muted),
            ),
          ),
          ShelfColumn(
            header: 'Time to beat',
            flex: 3,
            cell: (context, result) => Text(
              result.timesLabel,
              textAlign: TextAlign.right,
              style: style.caption.copyWith(color: tokens.muted),
            ),
          ),
        ],
        rows: results,
        isSelected: (result) => result.id == _selectedId,
        onRowTap: (result) => setState(() => _selectedId = result.id),
      );
    }

    return ShelfSheet(
      title: 'Search for a game',
      width: ShelfSheetWidth.wide,
      footer: ShelfSheetFooter(
        onCancel: () => Navigator.of(context).pop(),
        primary: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KeyHint('Enter'),
            const SizedBox(width: 8),
            ShelfButton(
              key: const Key('add-continue'),
              label: 'Continue in Creation Tool',
              kind: ShelfButtonKind.primary,
              onPressed: _selected == null ? null : _continue,
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShelfSearchInput(
            controller: _controller,
            hintText: 'Type in a game name...',
            autofocus: true,
            onChanged: _typed,
            onSubmitted: (_) => _continue(),
          ),
          const SizedBox(height: 10),
          content,
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Not the game you meant? ',
                style: style.caption.copyWith(color: tokens.muted),
              ),
              GestureDetector(
                key: const Key('add-custom'),
                behavior: HitTestBehavior.opaque,
                onTap: _custom,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'Create it as a custom game',
                    style: style.caption.copyWith(
                      color: tokens.accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
