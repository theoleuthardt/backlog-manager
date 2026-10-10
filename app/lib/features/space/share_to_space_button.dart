import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/mappers.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/backlog_scope.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/space.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The inspector action of a personal game: it copies the game into the
/// shared space, or, once it is there, links to the space. Only Steam games
/// can be shared, so a game without a Steam App ID gets a disabled button with
/// a hint. Nothing shows in the space itself or without an active space.
class ShareToSpaceButton extends ConsumerStatefulWidget {
  const ShareToSpaceButton({required this.entry, super.key});

  final BacklogEntry entry;

  @override
  ConsumerState<ShareToSpaceButton> createState() => _ShareToSpaceButtonState();
}

class _ShareToSpaceButtonState extends ConsumerState<ShareToSpaceButton> {
  bool _busy = false;

  Future<void> _share(int spaceId) async {
    final entry = widget.entry;
    setState(() => _busy = true);
    try {
      await ref
          .read(entriesProvider(spaceId).notifier)
          .createEntry(createRequestFrom(sharedCopyOf(entry)));
      ref.invalidate(entriesProvider(null));
      if (mounted) showShelfToast(context, sharedToastMessage(entry.title));
    } on Object catch (error) {
      if (mounted) {
        showShelfToast(
          context,
          ApiException.from(
            error,
            'Failed to add the game to your shared space',
          ).message,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spaceId = ref.watch(activeSpaceIdProvider);
    if (ref.watch(backlogScopeProvider) != null || spaceId == null) {
      return const SizedBox.shrink();
    }
    final entry = widget.entry;

    if (entry.inSharedSpace) {
      return ShelfButton(
        key: const Key('inspector-in-space'),
        label: 'In shared space',
        icon: Icons.people_outline,
        onPressed: () => context.go(AppRoutes.space),
      );
    }
    final shareable = canShareToSpace(entry);
    return Tooltip(
      message: shareable ? '' : shareToSpaceHint,
      child: ShelfButton(
        key: const Key('inspector-add-to-space'),
        label: 'Add to shared space',
        icon: Icons.people_outline,
        busy: _busy,
        onPressed: shareable && !_busy
            ? () => unawaited(_share(spaceId))
            : null,
      ),
    );
  }
}
