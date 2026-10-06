import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

sealed class ShelfMenuEntry {
  const ShelfMenuEntry();
}

/// An item of a menu. A [shortcut] hint is shown on the right, [checked]
/// (not null) adds a check column, [keepOpen] leaves the menu open after the
/// choice and a [submenu] makes the item open a nested menu instead.
class ShelfMenuItem extends ShelfMenuEntry {
  const ShelfMenuItem({
    required this.label,
    this.onSelected,
    this.icon,
    this.shortcut,
    this.danger = false,
    this.checked,
    this.keepOpen = false,
    this.submenu,
  });

  final String label;
  final VoidCallback? onSelected;
  final IconData? icon;
  final String? shortcut;
  final bool danger;
  final bool? checked;
  final bool keepOpen;
  final List<ShelfMenuEntry>? submenu;
}

class ShelfMenuDivider extends ShelfMenuEntry {
  const ShelfMenuDivider();
}

MenuStyle _menuStyle(ShelfTokens tokens) {
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(tokens.surface2),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: const WidgetStatePropertyAll(Color(0xCC000000)),
    elevation: const WidgetStatePropertyAll(16),
    padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: tokens.borderStrong),
      ),
    ),
  );
}

ButtonStyle _itemStyle(
  ShelfTokens tokens,
  ShelfTextStyles text, {
  required bool danger,
}) {
  bool active(Set<WidgetState> states) =>
      states.contains(WidgetState.hovered) ||
      states.contains(WidgetState.focused) ||
      states.contains(WidgetState.pressed);

  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => active(states) ? tokens.accent : Colors.transparent,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => active(states)
          ? tokens.onAccent
          : danger
          ? tokens.danger
          : tokens.foreground,
    ),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    minimumSize: const WidgetStatePropertyAll(Size(200, 30)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
    textStyle: WidgetStatePropertyAll(text.control),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );
}

List<Widget> _children(BuildContext context, List<ShelfMenuEntry> entries) {
  final tokens = Theme.of(context).extension<ShelfTokens>()!;
  final text = Theme.of(context).extension<ShelfTextStyles>()!;

  return [
    for (final entry in entries)
      switch (entry) {
        ShelfMenuDivider() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(
            height: 1,
            child: ColoredBox(
              key: const Key('menu-divider'),
              color: tokens.borderStrong,
            ),
          ),
        ),
        ShelfMenuItem(:final submenu?) => SubmenuButton(
          style: _itemStyle(tokens, text, danger: entry.danger),
          menuStyle: _menuStyle(tokens),
          menuChildren: _children(context, submenu),
          leadingIcon: _leading(entry, tokens),
          child: Text(entry.label),
        ),
        ShelfMenuItem() => MenuItemButton(
          style: _itemStyle(tokens, text, danger: entry.danger),
          closeOnActivate: !entry.keepOpen,
          onPressed: entry.onSelected,
          leadingIcon: _leading(entry, tokens),
          trailingIcon: entry.shortcut == null
              ? null
              : Text(
                  entry.shortcut!,
                  style: text.label.copyWith(
                    fontWeight: FontWeight.w400,
                    color: tokens.muted,
                  ),
                ),
          child: Text(entry.label),
        ),
      },
  ];
}

Widget? _leading(ShelfMenuItem item, ShelfTokens tokens) {
  if (item.icon != null) return Icon(item.icon, size: 16);
  final checked = item.checked;
  if (checked == null) return null;
  return SizedBox(
    width: 16,
    child: checked ? const Icon(Icons.check, size: 16) : null,
  );
}

/// A menu that opens from a trigger. [builder] draws the trigger and gets the
/// controller that opens and closes the menu.
class ShelfMenuAnchor extends StatelessWidget {
  const ShelfMenuAnchor({
    required this.entries,
    required this.builder,
    this.controller,
    super.key,
  });

  final List<ShelfMenuEntry> entries;
  final Widget Function(BuildContext context, MenuController controller)
  builder;
  final MenuController? controller;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;

    return MenuAnchor(
      controller: controller,
      style: _menuStyle(tokens),
      menuChildren: _children(context, entries),
      builder: (context, controller, child) => builder(context, controller),
    );
  }
}

/// Opens [entries] as a context menu where the user right-clicks [child].
class ContextMenuRegion extends StatefulWidget {
  const ContextMenuRegion({
    required this.entries,
    required this.child,
    super.key,
  });

  final List<ShelfMenuEntry> entries;
  final Widget child;

  @override
  State<ContextMenuRegion> createState() => _ContextMenuRegionState();
}

class _ContextMenuRegionState extends State<ContextMenuRegion> {
  final MenuController _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;

    return MenuAnchor(
      controller: _controller,
      style: _menuStyle(tokens),
      menuChildren: _children(context, widget.entries),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (details) =>
            _controller.open(position: details.localPosition),
        child: widget.child,
      ),
    );
  }
}

/// A popover: arbitrary [content] on the menu surface that opens from a
/// trigger, for value pickers that are more than a list of items.
class ShelfPopover extends StatelessWidget {
  const ShelfPopover({
    required this.content,
    required this.builder,
    this.controller,
    super.key,
  });

  final Widget content;
  final Widget Function(BuildContext context, MenuController controller)
  builder;
  final MenuController? controller;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;

    return MenuAnchor(
      controller: controller,
      style: _menuStyle(tokens),
      menuChildren: [content],
      builder: (context, controller, child) => builder(context, controller),
    );
  }
}
