import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/color_picker.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/categories.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the sheet that renames, recolours and deletes the categories of a
/// backlog ([spaceId] is the shared space, null for the personal backlog).
Future<void> showCategoryManager(BuildContext context, {int? spaceId}) {
  return showShelfSheet<void>(
    context,
    builder: (context) => _CategoryManagerSheet(spaceId: spaceId),
  );
}

class _CategoryManagerSheet extends ConsumerWidget {
  const _CategoryManagerSheet({required this.spaceId});

  final int? spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final categories =
        ref.watch(categoriesProvider(spaceId)).value ?? const <Category>[];

    return ShelfSheet(
      title: 'Manage categories',
      width: ShelfSheetWidth.compact,
      child: categories.isEmpty
          ? Text(
              "No categories yet - create one from a game's Overview tab.",
              style: style.caption.copyWith(color: tokens.muted),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: SingleChildScrollView(
                primary: false,
                child: Column(
                  children: [
                    for (final category in categories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CategoryRow(
                          key: Key('category-row-${category.id}'),
                          category: category,
                          otherNames: [
                            for (final other in categories)
                              if (other.id != category.id) other.name,
                          ],
                          spaceId: spaceId,
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _CategoryRow extends ConsumerStatefulWidget {
  const _CategoryRow({
    required this.category,
    required this.otherNames,
    required this.spaceId,
    super.key,
  });

  final Category category;
  final List<String> otherNames;
  final int? spaceId;

  @override
  ConsumerState<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends ConsumerState<_CategoryRow> {
  late final TextEditingController _name = TextEditingController(
    text: widget.category.name,
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commitName();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _error => categoryNameError(_name.text, widget.otherNames);

  Future<void> _save({String? name, String? color}) async {
    try {
      await ref
          .read(categoryActionsProvider(widget.spaceId))
          .update(widget.category.id, name: name, color: color);
    } on Object catch (error) {
      if (!mounted) return;
      _name.text = widget.category.name;
      showShelfToast(
        context,
        ApiException.from(error, 'Failed to update category').message,
      );
    }
  }

  void _commitName() {
    final trimmed = _name.text.trim();
    if (trimmed.isEmpty || _error.isNotEmpty) {
      setState(() => _name.text = widget.category.name);
      return;
    }
    if (trimmed != widget.category.name) _save(name: trimmed);
  }

  Future<void> _delete() async {
    final confirmed = await showShelfSheet<bool>(
      context,
      builder: (context) => _ConfirmDelete(name: widget.category.name),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(categoryActionsProvider(widget.spaceId))
          .delete(widget.category.id);
      if (mounted) {
        showShelfToast(context, 'Category "${widget.category.name}" deleted');
      }
    } on Object catch (error) {
      if (mounted) {
        showShelfToast(
          context,
          ApiException.from(error, 'Failed to delete category').message,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final error = _error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ShelfColorPicker(
              key: Key('category-color-${widget.category.id}'),
              value: widget.category.color,
              palette: categoryColors,
              label: 'Colour of ${widget.category.name}',
              onChanged: (hex) => _save(color: hex),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: Key('category-name-${widget.category.id}'),
                controller: _name,
                focusNode: _focus,
                style: style.fieldText,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  _commitName();
                  _focus.unfocus();
                },
              ),
            ),
            const SizedBox(width: 4),
            ShelfIconButton(
              key: Key('category-delete-${widget.category.id}'),
              icon: Icons.delete_outline,
              tooltip: 'Delete ${widget.category.name}',
              onPressed: _delete,
            ),
          ],
        ),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 52, top: 4),
            child: Text(
              error,
              style: style.caption.copyWith(color: tokens.danger),
            ),
          ),
      ],
    );
  }
}

class _ConfirmDelete extends StatelessWidget {
  const _ConfirmDelete({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;

    return ShelfSheet(
      title: 'Delete "$name"?',
      width: ShelfSheetWidth.compact,
      footer: ShelfSheetFooter(
        onCancel: () => Navigator.of(context).pop(false),
        primary: ShelfButton(
          key: const Key('category-delete-confirm'),
          label: 'Delete',
          kind: ShelfButtonKind.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
      child: Text(
        'The category is removed from every game that uses it. The games '
        'themselves stay in your backlog.',
        style: style.caption.copyWith(color: tokens.muted),
      ),
    );
  }
}
