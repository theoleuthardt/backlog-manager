import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:flutter/material.dart';

/// A column of a [ShelfDataTable]: its header text, how much of the width it
/// takes ([flex]) and how to draw its cell for a row.
class ShelfColumn<T> {
  const ShelfColumn({required this.header, required this.cell, this.flex = 1});

  final String header;
  final int flex;
  final Widget Function(BuildContext context, T row) cell;
}

const _checkColumnWidth = 40.0;

/// A table with a 34 px header of upper case captions and 48 px rows. A row
/// that can be tapped is tinted with the glow while hovered (with a 2 px line
/// on its left), a selected row with the soft accent. With
/// [onSelectionChanged] every row gets a checkbox and the header one that
/// selects all ([onSelectAll]).
class ShelfDataTable<T> extends StatelessWidget {
  const ShelfDataTable({
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.isSelected,
    this.onSelectionChanged,
    this.onSelectAll,
    super.key,
  });

  final List<ShelfColumn<T>> columns;
  final List<T> rows;
  final ValueChanged<T>? onRowTap;
  final bool Function(T row)? isSelected;
  final void Function(T row, bool selected)? onSelectionChanged;
  final ValueChanged<bool>? onSelectAll;

  bool get _selectable => onSelectionChanged != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(context),
        for (var i = 0; i < rows.length; i++) _row(context, i, rows[i]),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final selectedCount = rows
        .where((row) => isSelected?.call(row) ?? false)
        .length;
    final all = rows.isEmpty
        ? false
        : selectedCount == rows.length
        ? true
        : selectedCount == 0
        ? false
        : null;

    return SizedBox(
      key: const Key('table-header'),
      height: 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),
            if (_selectable)
              SizedBox(
                width: _checkColumnWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ShelfCheckbox(
                    key: const Key('table-select-all'),
                    value: all,
                    label: 'Select all',
                    onChanged: onSelectAll,
                  ),
                ),
              ),
            for (final column in columns)
              Expanded(
                flex: column.flex,
                child: Text(
                  column.header.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: text.sidebarLabel,
                ),
              ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int index, T row) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final selected = isSelected?.call(row) ?? false;

    return ShelfPressable(
      onPressed: onRowTap == null ? null : () => onRowTap!(row),
      borderRadius: ShelfRadius.control,
      builder: (context, state) => DecoratedBox(
        key: Key('table-row-$index'),
        decoration: BoxDecoration(
          color: selected
              ? tokens.accentSoft
              : state.hovered
              ? tokens.glowSoft
              : null,
          border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
        ),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              SizedBox(
                width: 2,
                height: 48,
                child: ColoredBox(
                  key: Key('table-row-$index-line'),
                  color: state.hovered ? tokens.glow : Colors.transparent,
                ),
              ),
              const SizedBox(width: 16),
              if (_selectable)
                SizedBox(
                  width: _checkColumnWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ShelfCheckbox(
                      key: Key('table-row-$index-check'),
                      value: selected,
                      onChanged: (value) => onSelectionChanged!(row, value),
                    ),
                  ),
                ),
              for (final column in columns)
                Expanded(
                  flex: column.flex,
                  child: DefaultTextStyle.merge(
                    style: Theme.of(context)
                        .extension<ShelfTextStyles>()!
                        .fieldText,
                    overflow: TextOverflow.ellipsis,
                    child: column.cell(context, row),
                  ),
                ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// A list row: optional [leading] and [trailing] widgets around a title and a
/// subtitle, at least 48 px high.
class ShelfListRow extends StatelessWidget {
  const ShelfListRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return ShelfPressable(
      onPressed: onTap,
      semanticLabel: title,
      builder: (context, state) => DecoratedBox(
        key: const Key('list-row-surface'),
        decoration: BoxDecoration(
          color: selected
              ? tokens.accentSoft
              : state.hovered
              ? tokens.glowSoft
              : null,
          borderRadius: BorderRadius.circular(ShelfRadius.control),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: text.control.copyWith(color: tokens.foreground),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: text.caption.copyWith(color: tokens.muted),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
