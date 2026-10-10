import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/space.dart';
import 'package:backlog_manager/features/common/entries_gate.dart';
import 'package:backlog_manager/features/library/library_page.dart';
import 'package:backlog_manager/features/space/invite_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The shared space: what to do without one ("Start a shared space"), with an
/// invitation (accept or decline), and for a member the library of the space.
class SpacePage extends ConsumerWidget {
  const SpacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = ref.watch(spaceProvider);

    return KeyedSubtree(
      key: const Key('page-space'),
      child: space.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () =>
            const CenteredMessage(text: 'Loading the shared space...'),
        error: (error, _) => CenteredMessage(
          text: ApiException.from(
            error,
            'Failed to load the shared space',
          ).message,
          action: ShelfButton(
            label: 'Try again',
            onPressed: () => ref.invalidate(spaceProvider),
          ),
        ),
        data: (space) => switch (space.stage) {
          SpaceStage.none => const _NoSpaceCard(),
          SpaceStage.invited => _InvitationCard(space: space),
          SpaceStage.active => LibraryPage(space: space),
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.text, required this.child});

  final String title;
  final String text;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 56, 28, 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(ShelfRadius.card),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 36, color: tokens.accent),
                  const SizedBox(height: 12),
                  Text(title, textAlign: TextAlign.center, style: style.page),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: style.body.copyWith(color: tokens.muted),
                  ),
                  const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoSpaceCard extends StatelessWidget {
  const _NoSpaceCard();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      title: 'Start a shared space',
      text:
          'Invite a friend by username to keep a co-op backlog together. '
          'Status and categories are shared, ratings and playtime stay your '
          'own, and only Steam games can be added.',
      child: InviteForm(),
    );
  }
}

class _InvitationCard extends ConsumerStatefulWidget {
  const _InvitationCard({required this.space});

  final Space space;

  @override
  ConsumerState<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<_InvitationCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        showShelfToast(context, ApiException.from(error, failure).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(spaceProvider.notifier);
    return _Card(
      title: widget.space.invitationTitle,
      text:
          'A shared backlog for games you play together. Your ratings and '
          'playtime stay your own.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShelfButton(
            key: const Key('space-accept'),
            label: 'Accept',
            kind: ShelfButtonKind.primary,
            onPressed: _busy
                ? null
                : () => unawaited(
                    _run(notifier.accept, 'Failed to accept invitation'),
                  ),
          ),
          const SizedBox(width: 10),
          ShelfButton(
            key: const Key('space-decline'),
            label: 'Decline',
            onPressed: _busy
                ? null
                : () => unawaited(
                    _run(notifier.leave, 'Failed to decline invitation'),
                  ),
          ),
        ],
      ),
    );
  }
}
