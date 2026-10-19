import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/data/space_backups_api.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/spinner.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/backups.dart';
import 'package:backlog_manager/domain/space.dart';
import 'package:backlog_manager/domain/space_backups.dart';
import 'package:backlog_manager/platform/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the backups of the Shared Space.
Future<void> showSpaceBackupsSheet(BuildContext context) {
  return showShelfSheet<void>(
    context,
    builder: (_) => const SpaceBackupsSheet(),
  );
}

/// The backups of the Shared Space: the automatic daily ones, manual ones of
/// either member and the safety backups before the space is emptied or
/// restored, plus the JSON export. A restore needs both members: one asks,
/// the other approves in this sheet (or declines).
class SpaceBackupsSheet extends ConsumerStatefulWidget {
  const SpaceBackupsSheet({super.key});

  @override
  ConsumerState<SpaceBackupsSheet> createState() => _SpaceBackupsSheetState();
}

class _SpaceBackupsSheetState extends ConsumerState<SpaceBackupsSheet> {
  final _name = TextEditingController();
  int? _renaming;
  bool _creating = false;
  bool _renameSaving = false;
  bool _saving = false;
  bool _answering = false;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(spaceBackupsProvider.notifier).refresh());
  }

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

  Future<void> _refresh() => ref.read(spaceBackupsProvider.notifier).refresh();

  void _reloadSpaceContent() {
    final spaceId = ref.read(activeSpaceIdProvider);
    ref
      ..invalidate(entriesProvider(spaceId))
      ..invalidate(categoriesProvider(spaceId))
      ..invalidate(entryCategoriesProvider(spaceId))
      ..invalidate(customStatusesProvider(spaceId));
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      await ref.read(spaceBackupsApiProvider).create();
      await _refresh();
      _toast('Backup created');
    } on Object catch (error) {
      _toast(_message(error, 'Failed to create backup'));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _save(
    Future<List<int>> Function() read,
    String name,
    String done,
    String failure,
  ) async {
    setState(() => _saving = true);
    try {
      final bytes = await read();
      final saved = await ref
          .read(fileSaverProvider)
          .save(suggestedName: name, bytes: bytes);
      if (saved) _toast(done);
    } on Object catch (error) {
      _toast(_message(error, failure));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _startRename(SpaceBackup backup) {
    _name.text = backup.name ?? '';
    setState(() => _renaming = backup.id);
  }

  Future<void> _saveRename() async {
    final id = _renaming;
    if (id == null || _renameSaving) return;
    setState(() => _renameSaving = true);
    try {
      await ref
          .read(spaceBackupsApiProvider)
          .rename(id, normalizeBackupName(_name.text));
      await _refresh();
      if (mounted) setState(() => _renaming = null);
      _toast('Backup renamed');
    } on Object catch (error) {
      _toast(_message(error, 'Failed to rename backup'));
    } finally {
      if (mounted) setState(() => _renameSaving = false);
    }
  }

  Future<void> _confirmRestore(SpaceBackup backup) async {
    final outcome = await showShelfSheet<SpaceRestoreOutcome>(
      context,
      builder: (_) => _RestoreSheet(backup: backup),
    );
    if (outcome == null) return;
    await _refresh();
    if (outcome.isRestored) {
      _reloadSpaceContent();
      _toast('Restored from the backup. Your previous state was saved.');
    } else {
      _toast('Restore requested');
    }
  }

  Future<void> _confirmDelete(SpaceBackup backup) async {
    final deleted = await showShelfSheet<bool>(
      context,
      builder: (_) => _DeleteSheet(backup: backup),
    );
    if (deleted != true) return;
    await _refresh();
    _toast('Backup deleted');
  }

  Future<void> _approve() async {
    setState(() => _answering = true);
    try {
      final result = await ref.read(spaceBackupsApiProvider).approveRestore();
      _reloadSpaceContent();
      await _refresh();
      _toast(result.message);
    } on Object catch (error) {
      await _refresh();
      _toast(_message(error, 'Failed to approve the restore'));
    } finally {
      if (mounted) setState(() => _answering = false);
    }
  }

  Future<void> _endRequest() async {
    setState(() => _answering = true);
    try {
      await ref.read(spaceBackupsApiProvider).withdrawRestoreRequest();
      await _refresh();
    } on Object catch (error) {
      _toast(_message(error, 'Failed to end the restore request'));
    } finally {
      if (mounted) setState(() => _answering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final backups = ref.watch(spaceBackupsProvider);
    final partner =
        ref.watch(spaceProvider).value?.partner?.username ?? 'your partner';
    final request = backups.value?.restoreRequest;

    return ShelfSheet(
      title: 'Space backups',
      description:
          'The space is backed up automatically once a day and right before '
          'it is emptied or restored. Either of you can back it up, a '
          'restore needs both of you.',
      width: ShelfSheetWidth.wide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (request != null) _requestBanner(tokens, style, request, partner),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ShelfButton(
                key: const Key('space-backup-create'),
                label: _creating ? 'Creating...' : 'Back up now',
                kind: ShelfButtonKind.primary,
                busy: _creating,
                onPressed: _creating ? null : _create,
              ),
              ShelfButton(
                key: const Key('space-export'),
                label: 'Export JSON',
                onPressed: _saving
                    ? null
                    : () => unawaited(
                        _save(
                          ref.read(spaceBackupsApiProvider).export,
                          'space-backlog.json',
                          'Export saved',
                          'Failed to export the space',
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          backups.when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => Row(
              key: const Key('space-backups-loading'),
              children: [
                const ShelfSpinner(size: 24),
                const SizedBox(width: 10),
                Text(
                  'Loading...',
                  style: style.caption.copyWith(color: tokens.muted),
                ),
              ],
            ),
            error: (error, _) => Text(
              'Failed to load the backups.',
              key: const Key('space-backups-error'),
              style: style.caption.copyWith(color: tokens.danger),
            ),
            data: (data) => data.backups.isEmpty
                ? Text(
                    'No backups yet.',
                    key: const Key('space-backups-empty'),
                    style: style.caption.copyWith(color: tokens.muted),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final backup in data.backups)
                        _row(tokens, style, backup, request != null),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _requestBanner(
    ShelfTokens tokens,
    ShelfTextStyles style,
    RestoreRequest request,
    String partner,
  ) {
    final left = request.timeLeft(DateTime.now().toUtc());
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        key: const Key('space-restore-request'),
        decoration: BoxDecoration(
          color: tokens.accentSoft,
          borderRadius: BorderRadius.circular(ShelfRadius.control),
          border: Border.all(color: tokens.accent),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.headline(partner),
                style: style.control.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                request.requestedByMe
                    ? 'The space stays as it is until $partner approves. '
                          '$left.'
                    : 'The space is replaced by that backup and its current '
                          'state is saved as a backup first. $left.',
                style: style.caption.copyWith(color: tokens.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: request.requestedByMe
                    ? [
                        ShelfButton(
                          key: const Key('space-restore-withdraw'),
                          label: 'Withdraw',
                          onPressed: _answering
                              ? null
                              : () => unawaited(_endRequest()),
                        ),
                      ]
                    : [
                        ShelfButton(
                          key: const Key('space-restore-approve'),
                          label: 'Approve',
                          kind: ShelfButtonKind.primary,
                          busy: _answering,
                          onPressed: _answering
                              ? null
                              : () => unawaited(_approve()),
                        ),
                        ShelfButton(
                          key: const Key('space-restore-decline'),
                          label: 'Decline',
                          onPressed: _answering
                              ? null
                              : () => unawaited(_endRequest()),
                        ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    ShelfTokens tokens,
    ShelfTextStyles style,
    SpaceBackup backup,
    bool requestOpen,
  ) {
    final renaming = _renaming == backup.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        key: Key('space-backup-${backup.id}'),
        decoration: BoxDecoration(
          color: tokens.surface2,
          borderRadius: BorderRadius.circular(ShelfRadius.control),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (renaming)
                _renameField(backup, style)
              else ...[
                Text.rich(
                  TextSpan(
                    text: backup.title,
                    style: style.control,
                    children: [
                      TextSpan(
                        text: '  ${backupDateLabel(backup.createdAt)}',
                        style: style.caption.copyWith(color: tokens.muted),
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ShelfButton(
                    key: Key('space-backup-restore-${backup.id}'),
                    label: 'Restore',
                    onPressed: requestOpen
                        ? null
                        : () => unawaited(_confirmRestore(backup)),
                  ),
                  ShelfButton(
                    key: Key('space-backup-rename-${backup.id}'),
                    label: 'Rename',
                    onPressed: () => _startRename(backup),
                  ),
                  ShelfButton(
                    key: Key('space-backup-download-${backup.id}'),
                    label: 'Download',
                    onPressed: _saving
                        ? null
                        : () => unawaited(
                            _save(
                              () => ref
                                  .read(spaceBackupsApiProvider)
                                  .download(backup.id),
                              backup.fileName,
                              'Backup saved',
                              'Failed to download backup',
                            ),
                          ),
                  ),
                  ShelfButton(
                    key: Key('space-backup-delete-${backup.id}'),
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

  Widget _renameField(SpaceBackup backup, ShelfTextStyles style) {
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
                key: const Key('space-backup-name'),
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
            key: const Key('space-backup-name-save'),
            label: 'Save',
            kind: ShelfButtonKind.primary,
            busy: _renameSaving,
            onPressed: () => unawaited(_saveRename()),
          ),
          const SizedBox(width: 8),
          ShelfButton(
            key: const Key('space-backup-name-cancel'),
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

  final SpaceBackup backup;

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
      final outcome = await ref
          .read(spaceBackupsApiProvider)
          .requestRestore(widget.backup.id);
      if (mounted) Navigator.of(context).pop(outcome);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ApiException.from(
          error,
          'Failed to ask for the restore',
        ).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final backup = widget.backup;
    final space = ref.watch(spaceProvider).value;
    final partner = space?.partnerIsActive ?? false
        ? space!.partner!.username
        : null;
    final what =
        'The games, categories and custom statuses of the space are replaced '
        'by the backup from ${backupDateLabel(backup.createdAt)} '
        '(${backupContentSummary(entryCount: backup.entryCount, categoryCount: backup.categoryCount)}), '
        'with the playtime, ratings and reviews of both of you.';
    return ShelfSheet(
      title: partner == null ? 'Restore this backup?' : 'Ask to restore?',
      width: ShelfSheetWidth.compact,
      footer: ShelfSheetFooter(
        onCancel: _busy ? null : () => Navigator.of(context).pop(),
        primary: ShelfButton(
          key: const Key('space-backup-restore-confirm'),
          label: partner == null
              ? (_busy ? 'Restoring...' : 'Restore')
              : (_busy ? 'Asking...' : 'Ask $partner'),
          kind: ShelfButtonKind.primary,
          busy: _busy,
          onPressed: _restore,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            partner == null
                ? '$what The current state is saved as a backup first, so you '
                      'can undo this.'
                : '$what $partner has to approve before it runs. The current '
                      'state is saved as a backup first, so you can undo it.',
            key: const Key('space-backup-restore-text'),
            style: style.body,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              key: const Key('space-backup-restore-error'),
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

  final SpaceBackup backup;

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
      await ref.read(spaceBackupsApiProvider).delete(widget.backup.id);
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
          key: const Key('space-backup-delete-confirm'),
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
            '"${backup.title}" from ${backupDateLabel(backup.createdAt)} is '
            'removed permanently for both of you. This cannot be undone.',
            key: const Key('space-backup-delete-text'),
            style: style.body,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              key: const Key('space-backup-delete-error'),
              style: style.caption.copyWith(color: tokens.danger),
            ),
          ],
        ],
      ),
    );
  }
}
