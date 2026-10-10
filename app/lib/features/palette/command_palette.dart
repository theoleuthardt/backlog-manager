import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/palette_search.dart';
import 'package:backlog_manager/features/palette/palette_actions.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/palette_registry.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Opens the command palette when [paletteOpenProvider] turns on and closes it
/// when that turns off, and registers the actions of the window. It sits
/// inside the navigator, because the palette is a sheet of it.
class PaletteHost extends ConsumerStatefulWidget {
  const PaletteHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PaletteHost> createState() => _PaletteHostState();
}

class _PaletteHostState extends ConsumerState<PaletteHost> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        registerShellPaletteActions(ProviderScope.containerOf(context));
      }
    });
  }

  void _show() {
    if (_showing) return;
    _showing = true;
    showShelfSheet<void>(
      context,
      builder: (_) => const CommandPalette(),
    ).whenComplete(() {
      _showing = false;
      if (mounted) ref.read(paletteOpenProvider.notifier).close();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(paletteOpenProvider, (_, open) {
      if (open) {
        _show();
      } else if (_showing) {
        Navigator.of(context).maybePop();
      }
    });
    return widget.child;
  }
}

sealed class _Item {
  const _Item();
}

class _GameItem extends _Item {
  const _GameItem(this.entry);

  final BacklogEntry entry;
}

class _ActionItem extends _Item {
  const _ActionItem(this.action);

  final PaletteAction action;
}

/// The command palette: an input, the games that match it and the actions
/// that match it. Arrow keys move the highlight, Enter runs the highlighted
/// row, Esc closes the sheet.
class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _controller = TextEditingController();
  int _highlight = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<BacklogEntry> _games() {
    final entries = ref.read(entriesProvider(null)).value ?? const [];
    return rankGames(entries, _controller.text);
  }

  List<PaletteAction> _actions() =>
      actionsMatching(ref.read(paletteRegistryProvider), _controller.text);

  List<_Item> _items() => [
    for (final entry in _games()) _GameItem(entry),
    for (final action in _actions()) _ActionItem(action),
  ];

  void _run(_Item item) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    switch (item) {
      case _GameItem(:final entry):
        router.go(
          Uri(
            path: AppRoutes.library,
            queryParameters: {'entry': '${entry.id}'},
          ).toString(),
        );
      case _ActionItem(:final action):
        action.run();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final items = _items();
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown && items.isNotEmpty) {
      setState(() => _highlight = (_highlight + 1) % items.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && items.isNotEmpty) {
      setState(() => _highlight = (_highlight - 1) % items.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && items.isNotEmpty) {
      _run(items[_highlight.clamp(0, items.length - 1)]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(entriesProvider(null))
      ..watch(paletteRegistryProvider);
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    final serverUrl = ref.watch(serverUrlProvider).value;
    final games = _games();
    final actions = _actions();
    final items = [
      for (final entry in games) _GameItem(entry),
      for (final action in actions) _ActionItem(action),
    ];
    final highlight = items.isEmpty
        ? -1
        : _highlight.clamp(0, items.length - 1);

    return SizedBox(
      width: 640,
      child: DecoratedBox(
        key: const Key('command-palette'),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(ShelfRadius.dialog),
          border: Border.all(color: tokens.borderStrong),
          boxShadow: [
            BoxShadow(
              color: tokens.shadow,
              blurRadius: 80,
              offset: const Offset(0, 24),
            ),
            BoxShadow(color: tokens.glowSoft, blurRadius: 60),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ShelfRadius.dialog - 1),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Focus(
                  onKeyEvent: _onKey,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: tokens.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            key: const Key('palette-input'),
                            controller: _controller,
                            autofocus: true,
                            onChanged: (_) => setState(() => _highlight = 0),
                            style: style.fieldText.copyWith(fontSize: 16),
                            decoration: const InputDecoration(
                              hintText: 'Type a command or search games',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                            ),
                          ),
                        ),
                        const _Kbd('Esc'),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: tokens.borderSubtle),
                Flexible(
                  child: items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Nothing matches "${_controller.text.trim()}"',
                              key: const Key('palette-empty'),
                              style: style.caption.copyWith(
                                color: tokens.muted,
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                          children: [
                            if (games.isNotEmpty) const _SectionLabel('Games'),
                            for (var i = 0; i < games.length; i++)
                              _GameRow(
                                entry: games[i],
                                serverUrl: serverUrl,
                                highlighted: highlight == i,
                                onHover: () => setState(() => _highlight = i),
                                onPressed: () => _run(items[i]),
                              ),
                            if (actions.isNotEmpty)
                              const _SectionLabel('Actions'),
                            for (var i = 0; i < actions.length; i++)
                              _ActionRow(
                                action: actions[i],
                                isMac: isMac,
                                highlighted: highlight == games.length + i,
                                onHover: () => setState(
                                  () => _highlight = games.length + i,
                                ),
                                onPressed: () => _run(items[games.length + i]),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Text(
        text.toUpperCase(),
        style: style.keyHint.copyWith(color: tokens.faint),
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(label, style: style.keyHint),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.height,
    required this.highlighted,
    required this.onHover,
    required this.onPressed,
    required this.semanticLabel,
    required this.child,
  });

  final double height;
  final bool highlighted;
  final VoidCallback onHover;
  final VoidCallback onPressed;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return MouseRegion(
      onHover: (_) {
        if (!highlighted) onHover();
      },
      child: ShelfPressable(
        borderRadius: 6,
        semanticLabel: semanticLabel,
        onPressed: onPressed,
        builder: (context, state) => DecoratedBox(
          decoration: BoxDecoration(
            color: highlighted ? tokens.glowSoft : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.entry,
    required this.serverUrl,
    required this.highlighted,
    required this.onHover,
    required this.onPressed,
  });

  final BacklogEntry entry;
  final String? serverUrl;
  final bool highlighted;
  final VoidCallback onHover;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final image = entryImage(serverUrl, entry.imageLink);
    return _Row(
      height: 40,
      highlighted: highlighted,
      onHover: onHover,
      onPressed: onPressed,
      semanticLabel: entry.title,
      child: Row(
        key: Key('palette-game-${entry.id}'),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 22,
              height: 30,
              child: image == null
                  ? ColoredBox(color: tokens.surface2)
                  : Image(image: image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              entry.title,
              overflow: TextOverflow.ellipsis,
              style: style.control,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              gameMeta(entry),
              overflow: TextOverflow.ellipsis,
              style: style.caption.copyWith(color: tokens.faint),
            ),
          ),
          if (highlighted) const _Kbd('Enter'),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.action,
    required this.isMac,
    required this.highlighted,
    required this.onHover,
    required this.onPressed,
  });

  final PaletteAction action;
  final bool isMac;
  final bool highlighted;
  final VoidCallback onHover;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final shortcut = action.shortcut;
    return _Row(
      height: 36,
      highlighted: highlighted,
      onHover: onHover,
      onPressed: onPressed,
      semanticLabel: action.label,
      child: Row(
        key: Key('palette-action-${action.id}'),
        children: [
          Expanded(child: Text(action.label, style: style.control)),
          if (shortcut != null) _Kbd(shortcut.display(isMac: isMac)),
        ],
      ),
    );
  }
}
