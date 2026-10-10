import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/backups_api.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/backups.dart';
import 'package:backlog_manager/features/settings/settings_widgets.dart';
import 'package:backlog_manager/platform/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The backups of the backlog: the automatic daily ones, manual ones and the
/// safety backups before something destructive. A restore replaces the
/// personal backlog and can itself be undone through the backup it makes.
class BackupsTab extends ConsumerStatefulWidget {
  const BackupsTab({super.key});

  @override
  ConsumerState<BackupsTab> createState() => _BackupsTabState();
}

class _BackupsTabState extends ConsumerState<BackupsTab> {
  final _name = TextEditingController();
  int? _renaming;
  bool _creating = false;
  bool _downloading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (mounted) showShelfToast(context, message);
  }

  String _message(Object error, String fallback) =>
      ApiException.from(error, fallback).message;

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      await ref.read(backupsApiProvider).create();
      ref.invalidate(backupsProvider);
      _toast('Backup created');
    } on Object catch (error) {
      _toast(_message(error, 'Failed to create backup'));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _startRename(Backup backup) {
    _name.text = backup.name ?? '';
    setState(() => _renaming = backup.id);
  }

  Future<void> _saveRename() async {
    final id = _renaming;
    if (id == null) return;
    try {
      await ref
          .read(backupsApiProvider)
          .rename(id, normalizeBackupName(_name.text));
      ref.invalidate(backupsProvider);
      if (mounted) setState(() => _renaming = null);
      _toast('Backup renamed');
    } on Object catch (error) {
      _toast(_message(error, 'Failed to rename backup'));
    }
  }

  Future<void> _download(Backup backup) async {
    setState(() => _downloading = true);
    try {
      final bytes = await ref.read(backupsApiProvider).download(backup.id);
      final saved = await ref
          .read(fileSaverProvider)
          .save(suggestedName: backup.fileName, bytes: bytes);
      if (saved) _toast('Backup saved');
    } on Object catch (error) {
      _toast(_message(error, 'Failed to download backup'));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _confirmRestore(Backup backup) async {
    final result = await showShelfSheet<RestoreResult>(
      context,
      builder: (_) => _RestoreSheet(backup: backup),
    );
    if (result == null) return;
    ref
      ..invalidate(entriesProvider(null))
      ..invalidate(categoriesProvider(null))
      ..invalidate(entryCategoriesProvider(null))
      ..invalidate(customStatusesProvider(null))
      ..invalidate(backupsProvider);
    _toast(result.message);
  }

  Future<void> _confirmDelete(Backup backup) async {
    final deleted = await showShelfSheet<bool>(
      context,
      builder: (_) => _DeleteSheet(backup: backup),
    );
    if (deleted != true) return;
    ref.invalidate(backupsProvider);
    _toast('Backup deleted');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final backups = ref.watch(backupsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingsTabTitle(
          title: 'Backups',
          subtitle:
              'Your backlog is backed up automatically once a day, and right '
              'before anything destructive. Restore an earlier state if '
              'something went wrong.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ShelfButton(
            key: const Key('backup-create'),
            label: _creating ? 'Creating...' : 'Back up now',
            kind: ShelfButtonKind.primary,
            busy: _creating,
            onPressed: _creating ? null : _create,
          ),
        ),
        const SizedBox(height: 16),
        backups.when(
          loading: () => Text(
            'Loading...',
            key: const Key('backups-loading'),
            style: style.caption.copyWith(color: tokens.muted),
          ),
          error: (error, _) => Text(
            'Failed to load backups.',
            key: const Key('backups-error'),
            style: style.caption.copyWith(color: tokens.danger),
          ),
          data: (list) => list.isEmpty
              ? Text(
                  'No backups yet.',
                  key: const Key('backups-empty'),
                  style: style.caption.copyWith(color: tokens.muted),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final backup in list) _row(context, backup)],
                ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, Backup backup) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final renaming = _renaming == backup.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        key: Key('backup-${backup.id}'),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(ShelfRadius.control),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: renaming
                    ? _renameField(backup, style)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: backup.title,
                              style: style.control,
                              children: [
                                TextSpan(
                                  text:
                                      '  ${backupDateLabel(backup.createdAt)}',
                                  style: style.caption.copyWith(
                                    color: tokens.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            backup.detail,
                            style: style.caption.copyWith(color: tokens.muted),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                children: [
                  ShelfButton(
                    key: Key('backup-restore-${backup.id}'),
                    label: 'Restore',
                    onPressed: () => unawaited(_confirmRestore(backup)),
                  ),
                  ShelfButton(
                    key: Key('backup-rename-${backup.id}'),
                    label: 'Rename',
                    onPressed: () => _startRename(backup),
                  ),
                  ShelfButton(
                    key: Key('backup-download-${backup.id}'),
                    label: 'Download',
                    onPressed: _downloading
                        ? null
                        : () => unawaited(_download(backup)),
                  ),
                  ShelfButton(
                    key: Key('backup-delete-${backup.id}'),
                    label: 'Delete',
                    onPressed: () => unawaited(_confirmDelete(backup)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _renameField(Backup backup, ShelfTextStyles style) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() => _renaming = null);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: ShelfHeight.input,
              child: TextField(
                key: const Key('backup-name'),
                controller: _name,
                autofocus: true,
                maxLength: maxBackupNameLength,
                buildCounter: (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
                onSubmitted: (_) => unawaited(_saveRename()),
                style: style.fieldText,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: backupKindLabel(backup.kind),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ShelfButton(
            key: const Key('backup-name-save'),
            label: 'Save',
            kind: ShelfButtonKind.primary,
            onPressed: () => unawaited(_saveRename()),
          ),
          const SizedBox(width: 8),
          ShelfButton(
            key: const Key('backup-name-cancel'),
            label: 'Cancel',
            kind: ShelfButtonKind.quiet,
            onPressed: () => setState(() => _renaming = null),
          ),
        ],
      ),
    );
  }
}

class _RestoreSheet extends ConsumerStatefulWidget {
  const _RestoreSheet({required this.backup});

  final Backup backup;

  @override
  ConsumerState<_RestoreSheet> createState() => _RestoreSheetState();
}

class _RestoreSheetState extends ConsumerState<_RestoreSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(backupsApiProvider)
          .restore(widget.backup.id);
      if (mounted) Navigator.of(context).pop(result);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ApiException.from(error, 'Failed to restore backup').message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final backup = widget.backup;
    return ShelfSheet(
      title: 'Restore this backup?',
      width: ShelfSheetWidth.compact,
      footer: ShelfSheetFooter(
        onCancel: _busy ? null : () => Navigator.of(context).pop(),
        primary: ShelfButton(
          key: const Key('backup-restore-confirm'),
          label: _busy ? 'Restoring...' : 'Restore',
          kind: ShelfButtonKind.primary,
          busy: _busy,
          onPressed: _restore,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your current games, categories and custom statuses are replaced '
            'by the backup from ${backupDateLabel(backup.createdAt)} '
            '(${backup.summary}). Your current state is saved as a backup '
            'first, so you can undo this.',
            key: const Key('backup-restore-text'),
            style: style.body,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              key: const Key('backup-restore-error'),
              style: style.caption.copyWith(color: tokens.danger),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeleteSheet extends ConsumerStatefulWidget {
  const _DeleteSheet({required this.backup});

  final Backup backup;

  @override
  ConsumerState<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends ConsumerState<_DeleteSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(backupsApiProvider).delete(widget.backup.id);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ApiException.from(error, 'Failed to delete backup').message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final backup = widget.backup;
    return ShelfSheet(
      title: 'Delete this backup?',
      width: ShelfSheetWidth.compact,
      footer: ShelfSheetFooter(
        onCancel: _busy ? null : () => Navigator.of(context).pop(),
        primary: ShelfButton(
          key: const Key('backup-delete-confirm'),
          label: 'Delete',
          kind: ShelfButtonKind.danger,
          busy: _busy,
          onPressed: _delete,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '"${backup.title}" from ${backupDateLabel(backup.createdAt)} '
            '(${backup.summary}) is removed permanently. This cannot be '
            'undone.',
            key: const Key('backup-delete-text'),
            style: style.body,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              key: const Key('backup-delete-error'),
              style: style.caption.copyWith(color: tokens.danger),
            ),
          ],
        ],
      ),
    );
  }
}
