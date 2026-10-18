import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/entry_mod_providers.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/spinner.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/entry_mod.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Mods tab of the inspector: the mods of a game with their names and
/// links, "Add mod", and per mod edit and remove. In a Shared Space the list
/// belongs to the game, so both members see and change the same one. Changes
/// are saved at once and independent of the entry form.
class ModsSection extends ConsumerWidget {
  const ModsSection({required this.entryId, this.spaceId, super.key});

  final int entryId;

  /// The Shared Space the game lives in; null for the personal backlog.
  final int? spaceId;

  ModsScope get _scope => (entryId: entryId, spaceId: spaceId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final mods = ref.watch(entryModsProvider(_scope));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (mods) {
          AsyncData(:final value) when value.isEmpty => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No mods yet. Add the mods you use for this game, with a link '
              'to where to get them.',
              key: const Key('mods-empty'),
              style: style.caption.copyWith(color: tokens.muted),
            ),
          ),
          AsyncData(:final value) => Column(
            children: [
              for (final mod in value)
                _ModRow(
                  mod: mod,
                  onEdit: () => unawaited(_edit(context, ref, mod)),
                  onRemove: () => unawaited(_remove(context, ref, mod)),
                ),
            ],
          ),
          AsyncError() => Text(
            'The mods could not be loaded.',
            key: const Key('mods-error'),
            style: style.caption.copyWith(color: tokens.danger),
          ),
          _ => const Center(child: ShelfSpinner()),
        },
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ShelfButton(
            key: const Key('mod-add'),
            label: 'Add mod',
            icon: Icons.add,
            onPressed: () => unawaited(_add(context, ref)),
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final input = await showShelfSheet<ModInput>(
      context,
      builder: (_) => const _ModSheet(),
    );
    if (input == null || !context.mounted) return;
    await _run(
      context,
      () =>
          ref.read(entryModActionsProvider(_scope)).add(input.name, input.url),
      'Failed to add the mod',
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, EntryMod mod) async {
    final input = await showShelfSheet<ModInput>(
      context,
      builder: (_) => _ModSheet(mod: mod),
    );
    if (input == null || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(entryModActionsProvider(_scope))
          .update(mod.id, input.name, input.url),
      'Failed to change the mod',
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, EntryMod mod) {
    return _run(
      context,
      () => ref.read(entryModActionsProvider(_scope)).remove(mod.id),
      'Failed to remove the mod',
    );
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String failure,
  ) async {
    try {
      await action();
    } on Object catch (error) {
      if (context.mounted) {
        showShelfToast(context, ApiException.from(error, failure).message);
      }
    }
  }
}

/// What the mod sheet returns: the trimmed name and the link or null.
class ModInput {
  const ModInput(this.name, this.url);

  final String name;
  final String? url;
}

class _ModRow extends ConsumerWidget {
  const _ModRow({
    required this.mod,
    required this.onEdit,
    required this.onRemove,
  });

  final EntryMod mod;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final url = mod.url;
    final uri = url == null ? null : Uri.tryParse(url);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(ShelfRadius.control),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mod.name,
                      style: style.body.copyWith(color: tokens.foreground),
                    ),
                    if (uri != null)
                      InkWell(
                        key: Key('mod-link-${mod.id}'),
                        onTap: () => ref.read(urlOpenerProvider)(uri),
                        child: Text(
                          url!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style.caption.copyWith(
                            color: tokens.accent,
                            decoration: TextDecoration.underline,
                            decorationColor: tokens.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ShelfIconButton(
                key: Key('mod-edit-${mod.id}'),
                icon: Icons.edit_outlined,
                tooltip: 'Edit ${mod.name}',
                onPressed: onEdit,
              ),
              ShelfIconButton(
                key: Key('mod-delete-${mod.id}'),
                icon: Icons.delete_outline,
                tooltip: 'Remove ${mod.name}',
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModSheet extends StatefulWidget {
  const _ModSheet({this.mod});

  final EntryMod? mod;

  @override
  State<_ModSheet> createState() => _ModSheetState();
}

class _ModSheetState extends State<_ModSheet> {
  late final _name = TextEditingController(text: widget.mod?.name ?? '');
  late final _url = TextEditingController(text: widget.mod?.url ?? '');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _save() {
    final problem = validateMod(_name.text, _url.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(ModInput(_name.text.trim(), modLink(_url.text)));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.mod != null;
    return ShelfSheet(
      title: editing ? 'Edit mod' : 'Add mod',
      width: ShelfSheetWidth.compact,
      footer: ShelfSheetFooter(
        onCancel: () => Navigator.of(context).pop(),
        primary: ShelfButton(
          key: const Key('mod-save'),
          label: editing ? 'Save mod' : 'Add mod',
          kind: ShelfButtonKind.primary,
          onPressed: _save,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShelfField(
            key: const Key('mod-name'),
            label: 'Name',
            hintText: 'Better Co-op',
            controller: _name,
            autofocus: true,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          ShelfField(
            key: const Key('mod-url'),
            label: 'Link (optional)',
            hintText: 'https://www.nexusmods.com/...',
            controller: _url,
            error: _error,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
    );
  }
}
