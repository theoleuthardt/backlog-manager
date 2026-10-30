import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/color_picker.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/menu_row.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/categories.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/common/category_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _panelWidth = 288.0;

/// The categories of one game: a chip with a colour dot and an x for each
/// category it has, a popover that toggles the existing categories or creates
/// a new one and adds it at once, and the manage sheet. Changes are saved at
/// once and independent of the entry form.
///
/// [CategoryPicker.pending] does the same for a game that does not exist yet
/// (the creation tool): the chosen categories are only held in [selected]
/// and reported through [onSelectedChanged]; a new category is still created
/// at once, since it belongs to the backlog.
class CategoryPicker extends ConsumerWidget {
  const CategoryPicker({required int this.entryId, this.spaceId, super.key})
    : selected = null,
      onSelectedChanged = null;

  const CategoryPicker.pending({
    required Set<int> this.selected,
    required ValueChanged<Set<int>> this.onSelectedChanged,
    this.spaceId,
    super.key,
  }) : entryId = null;

  final int? entryId;

  /// The Shared Space the game lives in; null for the personal backlog.
  final int? spaceId;

  final Set<int>? selected;
  final ValueChanged<Set<int>>? onSelectedChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned = _assigned(ref, entryId, spaceId, selected);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final category in assigned)
          _CategoryChip(
            category: category,
            onRemove: () =>
                _setAssigned(context, ref, category.id, assigned: false),
          ),
        ShelfPopover(
          content: _CategoryPanel(
            entryId: entryId,
            spaceId: spaceId,
            selected: selected,
            onSelectedChanged: onSelectedChanged,
          ),
          builder: (context, controller) => ShelfButton(
            key: const Key('category-add'),
            label: 'Category',
            icon: Icons.add,
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
        ),
        ShelfButton(
          key: const Key('category-manage'),
          label: 'Manage',
          icon: Icons.tune,
          onPressed: () => showCategoryManager(context, spaceId: spaceId),
        ),
      ],
    );
  }

  Future<void> _setAssigned(
    BuildContext context,
    WidgetRef ref,
    int categoryId, {
    required bool assigned,
  }) async {
    final selected = this.selected;
    if (selected != null) {
      onSelectedChanged?.call(
        assigned
            ? {...selected, categoryId}
            : ({...selected}..remove(categoryId)),
      );
      return;
    }
    try {
      await ref
          .read(categoryActionsProvider(spaceId))
          .setAssigned(entryId!, categoryId, assigned: assigned);
    } on Object catch (error) {
      if (context.mounted) {
        showShelfToast(
          context,
          ApiException.from(error, 'Failed to update categories').message,
        );
      }
    }
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.onRemove});

  final Category category;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;

    return DecoratedBox(
      key: Key('category-chip-${category.name}'),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.borderStrong),
      ),
      child: SizedBox(
        height: 26,
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorFromHex(category.color),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 8, height: 8),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 144),
                child: Text(
                  category.name,
                  overflow: TextOverflow.ellipsis,
                  style: style.label.copyWith(color: tokens.foreground),
                ),
              ),
              const SizedBox(width: 4),
              ShelfPressable(
                key: Key('category-remove-${category.name}'),
                borderRadius: 999,
                semanticLabel: 'Remove ${category.name}',
                onPressed: onRemove,
                builder: (context, state) => Padding(
                  padding: const EdgeInsets.all(3),
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

/// The categories the game has: those of [entryId] in the backlog, or the
/// chosen ones of a game that does not exist yet ([selected]).
List<Category> _assigned(
  WidgetRef ref,
  int? entryId,
  int? spaceId,
  Set<int>? selected,
) {
  if (selected != null) {
    final categories = ref.watch(categoriesProvider(spaceId)).value ?? const [];
    return [
      for (final category in categories)
        if (selected.contains(category.id)) category,
    ];
  }
  final byEntry = ref.watch(entryCategoriesProvider(spaceId)).value;
  return byEntry?[entryId] ?? const <Category>[];
}

class _CategoryPanel extends ConsumerStatefulWidget {
  const _CategoryPanel({
    required this.entryId,
    required this.spaceId,
    required this.selected,
    required this.onSelectedChanged,
  });

  final int? entryId;
  final int? spaceId;
  final Set<int>? selected;
  final ValueChanged<Set<int>>? onSelectedChanged;

  @override
  ConsumerState<_CategoryPanel> createState() => _CategoryPanelState();
}

class _CategoryPanelState extends ConsumerState<_CategoryPanel> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  String? _color;
  bool _creating = false;
  bool _paletteOpen = false;

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  List<Category> get _categories =>
      ref.read(categoriesProvider(widget.spaceId)).value ?? const [];

  String get _error => categoryNameError(_name.text, [
    for (final category in _categories) category.name,
  ]);

  bool get _canCreate =>
      !_creating && _name.text.trim().isNotEmpty && _error.isEmpty;

  Future<void> _toggle(int categoryId, {required bool assigned}) async {
    final selected = widget.selected;
    if (selected != null) {
      widget.onSelectedChanged?.call(
        assigned
            ? {...selected, categoryId}
            : ({...selected}..remove(categoryId)),
      );
      return;
    }
    try {
      await ref
          .read(categoryActionsProvider(widget.spaceId))
          .setAssigned(widget.entryId!, categoryId, assigned: assigned);
    } on Object catch (error) {
      if (mounted) {
        showShelfToast(
          context,
          ApiException.from(error, 'Failed to update categories').message,
        );
      }
    }
  }

  Future<void> _create() async {
    if (!_canCreate) return;
    final actions = ref.read(categoryActionsProvider(widget.spaceId));
    final name = _name.text.trim();
    final color = _color ?? nextCategoryColor(_categories.length);
    setState(() => _creating = true);
    final Category created;
    try {
      created = await actions.create(name, color);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _creating = false);
      showShelfToast(
        context,
        ApiException.from(error, 'Failed to create category').message,
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _creating = false;
      _color = null;
      _paletteOpen = false;
      _name.clear();
    });
    _nameFocus.requestFocus();
    final selected = widget.selected;
    if (selected != null) {
      widget.onSelectedChanged?.call({...selected, created.id});
      return;
    }
    try {
      await actions.setAssigned(widget.entryId!, created.id, assigned: true);
    } on Object catch (error) {
      if (!mounted) return;
      final reason = ApiException.from(error, 'an error occurred').message;
      showShelfToast(
        context,
        'Category "${created.name}" was created but could not be added to '
        'this game ($reason)',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final categories =
        ref.watch(categoriesProvider(widget.spaceId)).value ?? const [];
    final assignedIds = {
      for (final category in _assigned(
        ref,
        widget.entryId,
        widget.spaceId,
        widget.selected,
      ))
        category.id,
    };
    final color = _color ?? nextCategoryColor(categories.length);
    final error = _error;

    return SizedBox(
      width: _panelWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (categories.isNotEmpty) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 192),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    children: [
                      for (final category in sortCategoriesByName(categories))
                        ShelfMenuRow(
                          key: Key('category-option-${category.name}'),
                          label: category.name,
                          leading: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorFromHex(category.color),
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox(width: 12, height: 12),
                          ),
                          trailing: assignedIds.contains(category.id)
                              ? const Icon(Icons.check, size: 16)
                              : null,
                          onPressed: () => _toggle(
                            category.id,
                            assigned: !assignedIds.contains(category.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 17, color: tokens.borderSubtle),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'New Category',
                  style: style.label.copyWith(color: tokens.muted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ShelfColorSwatch(
                      value: color,
                      label: 'Category Colour',
                      onPressed: () =>
                          setState(() => _paletteOpen = !_paletteOpen),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('new-category-name'),
                        controller: _name,
                        focusNode: _nameFocus,
                        style: style.fieldText,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Co-op nights',
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _create(),
                      ),
                    ),
                  ],
                ),
                if (_paletteOpen) ...[
                  const SizedBox(height: 8),
                  ShelfColorPalette(
                    value: color,
                    palette: categoryColors,
                    onChanged: (hex) => setState(() => _color = hex),
                  ),
                ],
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    error,
                    style: style.caption.copyWith(color: tokens.danger),
                  ),
                ],
                const SizedBox(height: 8),
                ShelfButton(
                  key: const Key('category-create'),
                  label: 'Create and add',
                  kind: ShelfButtonKind.primary,
                  busy: _creating,
                  onPressed: _create,
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
