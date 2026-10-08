import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/chips.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/design/widgets/segmented.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/domain/filter_tokens.dart';
import 'package:backlog_manager/domain/sort_entries.dart';
import 'package:backlog_manager/features/library/library_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _pickerWidth = 260.0;

/// The 44 px strip under the library toolbar: one token per active filter,
/// the dashed "+ Add filter" token, and on the right the owned-only switch,
/// reset, sorting and the grid or list toggle.
class FilterBar extends ConsumerWidget {
  const FilterBar({required this.gutter, super.key});

  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final filters = ref.watch(effectiveFiltersProvider);
    final active = ref.watch(activeFilterCountProvider);

    return SizedBox(
      key: const Key('filter-bar'),
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.foreground.withValues(alpha: 0.03),
          border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 14, color: tokens.muted),
              const SizedBox(width: 6),
              Text('Filter', style: style.label.copyWith(color: tokens.muted)),
              const SizedBox(width: 12),
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final token in filterTokens(filters)) ...[
                          _FilterTokenView(token: token),
                          const SizedBox(width: 8),
                        ],
                        const _AddFilter(),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Owned only',
                style: style.caption.copyWith(color: tokens.muted),
              ),
              const SizedBox(width: 8),
              ShelfSwitch(
                key: const Key('owned-only'),
                label: 'Owned only',
                value: filters.ownedOnly,
                onChanged: ref.read(filtersProvider.notifier).setOwnedOnly,
              ),
              if (active > 0) ...[
                const SizedBox(width: 8),
                ShelfButton(
                  key: const Key('filter-reset'),
                  label: 'Reset',
                  kind: ShelfButtonKind.quiet,
                  onPressed: ref.read(filtersProvider.notifier).reset,
                ),
              ],
              const SizedBox(width: 12),
              const _SortAndView(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortAndView extends ConsumerWidget {
  const _SortAndView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(libraryViewProvider);
    final notifier = ref.read(libraryViewProvider.notifier);

    return Row(
      children: [
        ShelfMenuAnchor(
          entries: [
            for (final option in SortOption.values)
              ShelfMenuItem(
                label: option.label,
                checked: option == view.sortBy,
                onSelected: () => notifier.setSort(option),
              ),
          ],
          builder: (context, controller) => ShelfButton(
            label: 'Sort: ${view.sortBy.label}',
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
        ),
        const SizedBox(width: 4),
        ShelfIconButton(
          icon: view.direction == SortDirection.asc
              ? Icons.arrow_upward
              : Icons.arrow_downward,
          tooltip: 'Sort direction',
          onPressed: notifier.toggleDirection,
        ),
        const SizedBox(width: 12),
        ShelfSegmented<LibraryLayout>(
          segments: const [
            ShelfSegment(value: LibraryLayout.grid, label: 'Grid'),
            ShelfSegment(value: LibraryLayout.list, label: 'List'),
          ],
          value: view.layout,
          onChanged: notifier.setLayout,
        ),
      ],
    );
  }
}

/// A token of an active filter: the field in muted, its value, and an x that
/// removes the filter. Tapping the text opens the picker of the field.
class _FilterTokenView extends ConsumerWidget {
  const _FilterTokenView({required this.token});

  final FilterToken token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final name = token.field.name;

    return ShelfPopover(
      content: FilterPicker(field: token.field),
      builder: (context, controller) => DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: tokens.borderStrong),
        ),
        child: SizedBox(
          height: 26,
          child: Row(
            children: [
              ShelfPressable(
                key: Key('filter-token-$name'),
                borderRadius: 7,
                semanticLabel: 'Edit filter ${token.field.label}',
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                builder: (context, state) => Padding(
                  padding: const EdgeInsets.only(left: 10, right: 4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          token.field.label,
                          style: style.label.copyWith(color: tokens.muted),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            token.value,
                            overflow: TextOverflow.ellipsis,
                            style: style.label.copyWith(
                              color: tokens.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ShelfPressable(
                key: Key('filter-remove-$name'),
                borderRadius: 4,
                semanticLabel: 'Remove filter ${token.field.label}',
                onPressed: () =>
                    ref.read(filtersProvider.notifier).clear(token.field),
                builder: (context, state) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.close,
                    size: 12,
                    color: state.hovered ? tokens.foreground : tokens.faint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dashed "+ Add filter" token. It opens the searchable list of fields
/// and then the value picker of the chosen one.
class _AddFilter extends StatelessWidget {
  const _AddFilter();

  @override
  Widget build(BuildContext context) {
    return ShelfPopover(
      content: const _AddFilterContent(),
      builder: (context, controller) => ShelfChip(
        key: const Key('add-filter'),
        label: '+ Add filter',
        kind: ShelfChipKind.add,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _AddFilterContent extends ConsumerStatefulWidget {
  const _AddFilterContent();

  @override
  ConsumerState<_AddFilterContent> createState() => _AddFilterContentState();
}

class _AddFilterContentState extends ConsumerState<_AddFilterContent> {
  FilterField? _field;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final field = _field;
    if (field != null) {
      return _PickerWithHeader(
        field: field,
        onBack: () => setState(() => _field = null),
      );
    }
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final hasCategories = ref.watch(
      filterOptionsProvider.select((options) => options.categories.isNotEmpty),
    );
    final query = _query.trim().toLowerCase();
    final fields = [
      for (final field in FilterField.values)
        if ((field != FilterField.category || hasCategories) &&
            field.label.toLowerCase().contains(query))
          field,
    ];

    return SizedBox(
      width: _pickerWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                Icon(Icons.search, size: 14, color: tokens.faint),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('add-filter-search'),
                    autofocus: true,
                    style: style.fieldText,
                    decoration: InputDecoration(
                      hintText: 'Filter by...',
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintStyle: style.fieldText.copyWith(color: tokens.faint),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.borderSubtle),
          const SizedBox(height: 4),
          for (final field in fields)
            _MenuRow(
              key: Key('add-filter-field-${field.name}'),
              label: field.label,
              trailing: Icon(
                Icons.chevron_right,
                size: 16,
                color: tokens.faint,
              ),
              onPressed: () => setState(() => _field = field),
            ),
        ],
      ),
    );
  }
}

class _PickerWithHeader extends StatelessWidget {
  const _PickerWithHeader({required this.field, required this.onBack});

  final FilterField field;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;

    return SizedBox(
      width: _pickerWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MenuRow(
            key: const Key('add-filter-back'),
            label: field.label,
            leading: Icon(Icons.chevron_left, size: 16, color: tokens.muted),
            labelStyle: style.label.copyWith(color: tokens.muted),
            onPressed: onBack,
          ),
          Divider(height: 1, color: tokens.borderSubtle),
          FilterPicker(field: field),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.labelStyle,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? leading;
  final Widget? trailing;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;

    return ShelfPressable(
      borderRadius: 6,
      semanticLabel: label,
      onPressed: onPressed,
      builder: (context, state) => DecoratedBox(
        decoration: BoxDecoration(
          color: state.hovered ? tokens.glowSoft : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 4)],
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle ?? style.control,
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The value picker of one filter field: a list with a check per value for the
/// list fields, a minimum and a maximum with a slider for the ranges. Changes
/// apply at once.
class FilterPicker extends ConsumerWidget {
  const FilterPicker({required this.field, super.key});

  final FilterField field;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: _pickerWidth,
      child: field.isRange
          ? _RangePicker(field: field)
          : _ListPicker(field: field),
    );
  }
}

class _ListPicker extends ConsumerWidget {
  const _ListPicker({required this.field});

  final FilterField field;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final options = ref.watch(
      filterOptionsProvider.select((options) => options.of(field)),
    );
    final selected = listValues(ref.watch(filtersProvider), field);

    void toggle(String value) {
      final next = selected.contains(value)
          ? [
              for (final item in selected)
                if (item != value) item,
            ]
          : [...selected, value];
      ref.read(filtersProvider.notifier).setList(field, next);
    }

    if (options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Nothing to pick yet',
          style: style.caption.copyWith(color: tokens.muted),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final value in options)
                _MenuRow(
                  key: Key('filter-option-$value'),
                  label: value,
                  leading: ShelfCheckbox(
                    value: selected.contains(value),
                    onChanged: (_) => toggle(value),
                  ),
                  onPressed: () => toggle(value),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangePicker extends ConsumerStatefulWidget {
  const _RangePicker({required this.field});

  final FilterField field;

  @override
  ConsumerState<_RangePicker> createState() => _RangePickerState();
}

class _RangePickerState extends ConsumerState<_RangePicker> {
  late double _low;
  late double _high;
  late final TextEditingController _lowText;
  late final TextEditingController _highText;

  @override
  void initState() {
    super.initState();
    final bound = ref.read(filterBoundsProvider).of(widget.field);
    final range = rangeValue(ref.read(filtersProvider), widget.field);
    _low = (range?.$1 ?? 0).toDouble();
    _high = (range?.$2 ?? bound).toDouble();
    _lowText = TextEditingController(text: _format(_low));
    _highText = TextEditingController(text: _format(_high));
  }

  @override
  void dispose() {
    _lowText.dispose();
    _highText.dispose();
    super.dispose();
  }

  String _format(double value) {
    return value == value.truncateToDouble()
        ? value.truncate().toString()
        : value.toString();
  }

  void _commit() {
    ref.read(filtersProvider.notifier).setRange(widget.field, (_low, _high));
  }

  void _setFromText(double bound) {
    final low = double.tryParse(_lowText.text.trim()) ?? _low;
    final high = double.tryParse(_highText.text.trim()) ?? _high;
    final clampedLow = low.clamp(0, bound).toDouble();
    final clampedHigh = high.clamp(clampedLow, bound).toDouble();
    setState(() {
      _low = clampedLow;
      _high = clampedHigh;
      _lowText.text = _format(_low);
      _highText.text = _format(_high);
    });
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final bound = ref.watch(filterBoundsProvider).of(widget.field).toDouble();
    final unit = widget.field.unit;

    Widget numberField(Key key, TextEditingController controller) {
      return Expanded(
        child: TextField(
          key: key,
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: style.fieldText,
          textAlign: TextAlign.center,
          onSubmitted: (_) => _setFromText(bound),
          onTapOutside: (_) => _setFromText(bound),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              numberField(const Key('range-min'), _lowText),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'to',
                  style: style.caption.copyWith(color: tokens.muted),
                ),
              ),
              numberField(const Key('range-max'), _highText),
              if (unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    unit.trim(),
                    style: style.caption.copyWith(color: tokens.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          RangeSlider(
            key: const Key('range-slider'),
            min: 0,
            max: bound,
            divisions: bound.round(),
            values: RangeValues(_low.clamp(0, bound), _high.clamp(0, bound)),
            onChanged: (values) => setState(() {
              _low = values.start;
              _high = values.end;
              _lowText.text = _format(_low);
              _highText.text = _format(_high);
            }),
            onChangeEnd: (_) => _commit(),
          ),
        ],
      ),
    );
  }
}
