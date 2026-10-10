import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/sse.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/igdb_sync_api.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/igdb_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _notConfigured = 'IGDB integration is not configured';
const _failed = 'Failed to sync IGDB data';

/// Opens the confirmation sheet of the IGDB sync.
Future<void> showIgdbSyncSheet(BuildContext context) {
  return showShelfSheet<void>(context, builder: (_) => const IgdbSyncSheet());
}

/// Explains the IGDB sync, shows how many games it would look up and runs it
/// with a progress bar. While it runs the sheet cannot be closed.
class IgdbSyncSheet extends ConsumerStatefulWidget {
  const IgdbSyncSheet({super.key});

  @override
  ConsumerState<IgdbSyncSheet> createState() => _IgdbSyncSheetState();
}

class _IgdbSyncSheetState extends ConsumerState<IgdbSyncSheet> {
  StreamSubscription<SseEvent>? _subscription;
  bool _running = false;
  int? _processed;
  int? _total;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _toast(String message) {
    if (mounted) showShelfToast(context, message);
  }

  void _start() {
    final api = ref.read(igdbSyncApiProvider);
    final entries = entriesProvider(null);
    final container = ProviderScope.containerOf(context);
    final navigator = Navigator.of(context);
    setState(() {
      _running = true;
      _processed = null;
      _total = null;
    });

    void finish(String message, {bool close = false}) {
      _subscription = null;
      if (mounted) {
        setState(() => _running = false);
        _toast(message);
        if (close) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => navigator.maybePop(),
          );
        }
      }
    }

    _subscription = api.sync().listen(
      (event) {
        switch (event) {
          case SseProgress(:final processed, :final total):
            if (mounted) {
              setState(() {
                _processed = processed;
                _total = total;
              });
            }
          case SseDone(:final data):
            container.invalidate(entries);
            finish(
              syncResultMessage(data is List ? data.length : 0),
              close: true,
            );
          case SseError(:final message):
            finish(message);
        }
      },
      onError: (Object error) {
        final api = ApiException.from(error, _failed);
        finish(api.statusCode == 503 ? _notConfigured : api.message);
      },
      onDone: () {
        if (_running) finish(_failed);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final pending = ref.watch(igdbPendingCountProvider);
    final count = pending.value;

    return PopScope(
      canPop: !_running,
      child: ShelfSheet(
        title: 'Sync IGDB game data',
        description:
            'Looks up every game that is missing a genre or description on '
            'IGDB and fills in what is missing: genre, description, trailer '
            'and beat times. Values you entered yourself are never '
            'overwritten.',
        width: ShelfSheetWidth.compact,
        footer: ShelfSheetFooter(
          onCancel: _running ? null : () => Navigator.of(context).maybePop(),
          primary: ShelfButton(
            key: const Key('igdb-sync-start'),
            label: _running ? 'Syncing...' : 'Start sync',
            kind: ShelfButtonKind.primary,
            busy: _running,
            onPressed: !_running && count != null && count > 0 ? _start : null,
          ),
        ),
        child: _running
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShelfProgressBar(value: syncFraction(_processed, _total)),
                  const SizedBox(height: 6),
                  Text(
                    progressLabel(_processed, _total),
                    key: const Key('igdb-sync-progress'),
                    style: style.caption.copyWith(color: tokens.muted),
                  ),
                ],
              )
            : Text(
                pendingLabel(count, failed: pending.hasError),
                key: const Key('igdb-sync-pending'),
                style: style.caption.copyWith(color: tokens.muted),
              ),
      ),
    );
  }
}
