import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/menu_row.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/design/widgets/select.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/status_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _listWidth = 260.0;

/// The drop-down every place that picks a status uses: the default statuses,
/// the value of the entry when it is none of the known ones (a CSV import, for
/// example), then the custom statuses of the backlog each with a delete button,
/// and "Add Status" at the end.
class StatusSelect extends ConsumerWidget {
  const StatusSelect({
    required this.value,
    required this.onChanged,
    this.spaceId,
    this.placeholder = 'Select status',
    super.key,
  });

  final String value;

  /// Called with the chosen status, with the new one after it was created and
  /// with '' when the selected custom status was deleted.
  final ValueChanged<String> onChanged;

  /// The shared space whose custom statuses are offered; null for the personal
  /// backlog.
  final int? spaceId;
  final String placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ShelfPopover(
      content: _StatusList(
        value: value,
        spaceId: spaceId,
        onChanged: onChanged,
      ),
      builder: (context, controller) => ShelfSelectTrigger(
        key: const Key('status-select'),
        text: value.isEmpty ? placeholder : value,
        placeholder: value.isEmpty,
        semanticLabel: 'Status',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _StatusList extends ConsumerWidget {
  const _StatusList({
    required this.value,
    required this.spaceId,
    required this.onChanged,
  });

  final String value;
  final int? spaceId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final custom = ref.watch(customStatusesProvider(spaceId)).value ?? const [];
    final known =
        defaultStatuses.contains(value) ||
        custom.any((status) => status.name == value);
    final menu = MenuController.maybeOf(context);

    void choose(String status) {
      onChanged(status);
      menu?.close();
    }

    Future<void> delete(int id, String name) async {
      try {
        await ref.read(customStatusActionsProvider(spaceId)).delete(id);
        if (value == name) onChanged('');
        if (context.mounted) showShelfToast(context, 'Status "$name" deleted');
      } on Object catch (error) {
        if (context.mounted) {
          showShelfToast(
            context,
            ApiException.from(error, 'Failed to delete status').message,
          );
        }
      }
    }

    return SizedBox(
      width: _listWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final status in defaultStatuses)
            _option(status, selected: status == value, onPressed: choose),
          if (value.isNotEmpty && !known)
            _option(value, selected: true, onPressed: choose),
          for (final status in custom)
            _option(
              status.name,
              selected: status.name == value,
              onPressed: choose,
              trailing: ShelfPressable(
                key: Key('status-delete-${status.name}'),
                borderRadius: 4,
                semanticLabel: 'Delete status ${status.name}',
                onPressed: () => delete(status.id, status.name),
                builder: (context, state) => Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: state.hovered ? tokens.danger : tokens.faint,
                ),
              ),
            ),
          Divider(height: 9, color: tokens.borderSubtle),
          ShelfMenuRow(
            key: const Key('status-add'),
            label: 'Add Status',
            leading: Icon(
              Icons.add_circle_outline,
              size: 16,
              color: tokens.muted,
            ),
            onPressed: () {
              menu?.close();
              showShelfSheet<void>(
                context,
                builder: (context) =>
                    _AddStatusSheet(spaceId: spaceId, onCreated: onChanged),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _option(
    String status, {
    required bool selected,
    required ValueChanged<String> onPressed,
    Widget? trailing,
  }) {
    return ShelfMenuRow(
      key: Key('status-option-$status'),
      label: status,
      leading: SizedBox(
        width: 16,
        child: selected ? const Icon(Icons.check, size: 16) : null,
      ),
      trailing: trailing,
      onPressed: () => onPressed(status),
    );
  }
}

class _AddStatusSheet extends ConsumerStatefulWidget {
  const _AddStatusSheet({required this.spaceId, required this.onCreated});

  final int? spaceId;
  final ValueChanged<String> onCreated;

  @override
  ConsumerState<_AddStatusSheet> createState() => _AddStatusSheetState();
}

class _AddStatusSheetState extends ConsumerState<_AddStatusSheet> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _error {
    final custom =
        ref.read(customStatusesProvider(widget.spaceId)).value ?? const [];
    return statusNameError(_name.text, [
      for (final status in custom) status.name,
    ]);
  }

  bool get _canCreate =>
      !_busy && _name.text.trim().isNotEmpty && _error.isEmpty;

  Future<void> _create() async {
    if (!_canCreate) return;
    setState(() => _busy = true);
    try {
      final created = await ref
          .read(customStatusActionsProvider(widget.spaceId))
          .create(_name.text.trim());
      widget.onCreated(created.name);
      if (!mounted) return;
      showShelfToast(context, 'Status "${created.name}" created');
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showShelfToast(
        context,
        ApiException.from(error, 'Failed to create status').message,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShelfSheet(
      title: 'Add status',
      width: ShelfSheetWidth.compact,
      footer: ShelfSheetFooter(
        onCancel: () => Navigator.of(context).maybePop(),
        primary: ShelfButton(
          key: const Key('status-create'),
          label: 'Create',
          kind: ShelfButtonKind.primary,
          busy: _busy,
          onPressed: _create,
        ),
      ),
      child: ShelfField(
        key: const Key('status-name-field'),
        label: 'Name',
        hintText: 'For example Replaying',
        controller: _name,
        autofocus: true,
        error: _error.isEmpty ? null : _error,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _create(),
      ),
    );
  }
}
