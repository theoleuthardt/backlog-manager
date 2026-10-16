import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The search of the library and of the Shared Space, in the header row of the
/// page next to the counts, where the games are. It filters the list as you
/// type, `/` focuses it, and its border lights up on hover and focus. Its key
/// hint is `/`; Cmd/Ctrl+K opens the command palette instead.
class LibrarySearchField extends ConsumerStatefulWidget {
  const LibrarySearchField({super.key});

  @override
  ConsumerState<LibrarySearchField> createState() => _LibrarySearchFieldState();
}

class _LibrarySearchFieldState extends ConsumerState<LibrarySearchField> {
  var _hovered = false;

  late final TextEditingController _controller = TextEditingController(
    text: ref.read(filtersProvider).search,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    ref.listen(filtersProvider.select((filters) => filters.search), (_, next) {
      if (_controller.text != next) _controller.text = next;
    });

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(ShelfRadius.control),
      borderSide: BorderSide(color: color),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        height: 34,
        child: TextField(
          key: const Key('search-field'),
          controller: _controller,
          onChanged: ref.read(filtersProvider.notifier).setSearch,
          focusNode: ref.watch(searchFocusNodeProvider),
          style: text.fieldText,
          decoration: InputDecoration(
            hintText: 'Search your games',
            prefixIcon: Icon(Icons.search, size: 16, color: tokens.muted),
            prefixIconConstraints: const BoxConstraints(minWidth: 34),
            suffixIcon: Center(
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.surface3,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: tokens.borderStrong),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    child: Text('/', style: text.keyHint),
                  ),
                ),
              ),
            ),
            filled: true,
            fillColor: tokens.surface2,
            enabledBorder: border(
              _hovered ? tokens.accent : tokens.borderStrong,
            ),
            focusedBorder: border(tokens.glow),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
        ),
      ),
    );
  }
}
