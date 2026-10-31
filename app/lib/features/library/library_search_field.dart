import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/design/form_factor.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/type_gate.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The search of the library and of the Shared Space, on the heading line of the
/// header, where the games are. It filters the list as you
/// type, Cmd/Ctrl+S focuses it, and its border lights up on hover and focus. Its
/// shortcut hint is Cmd/Ctrl+S; Cmd/Ctrl+K opens the command palette instead.
/// A touch screen has no hint, and a gamepad types in it only after A
/// ([TypeGate]).
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
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    final touch = ShelfFormFactor.isTouch(context);
    ref.listen(filtersProvider.select((filters) => filters.search), (_, next) {
      if (_controller.text != next) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(ShelfRadius.control),
      borderSide: BorderSide(color: color),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        height: ShelfFormFactor.heightFor(context, 34),
        child: TypeGate(
          focusNode: ref.watch(searchFocusNodeProvider),
          builder: (context, focusNode) => TextField(
            key: const Key('search-field'),
            controller: _controller,
            onChanged: ref.read(filtersProvider.notifier).setSearch,
            focusNode: focusNode,
            style: text.fieldText,
            decoration: InputDecoration(
              hintText: 'Search your games',
              prefixIcon: Icon(Icons.search, size: 16, color: tokens.muted),
              prefixIconConstraints: const BoxConstraints(minWidth: 34),
              suffixIcon: touch
                  ? null
                  : Center(
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
                            child: Text(
                              isMac ? '⌘S' : 'Ctrl S',
                              style: text.keyHint,
                            ),
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
      ),
    );
  }
}
