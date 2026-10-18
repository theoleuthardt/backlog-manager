import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/space.dart';
import 'package:backlog_manager/features/common/user_avatar.dart';
import 'package:backlog_manager/features/space/invite_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The two members of the space as overlapping avatars with their initials.
class MemberAvatars extends StatelessWidget {
  const MemberAvatars({required this.space, super.key});

  final Space space;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final me = space.members.where((member) => member.isMe).firstOrNull;
    final partner = space.partner;

    Widget avatar(SpaceMember member, Color color) => DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: tokens.background, width: 2),
      ),
      child: SizedBox(
        width: 28,
        height: 28,
        child: UserAvatar(
          userId: member.userId,
          version: member.avatarUpdatedAt,
          size: 24,
          fallback: Center(
            child: Text(
              memberInitials(member.username),
              style: Theme.of(context)
                  .extension<ShelfTextStyles>()!
                  .caption
                  .copyWith(
                    color: tokens.onAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      key: const Key('space-avatars'),
      width: partner == null ? 28 : 46,
      height: 28,
      child: Stack(
        children: [
          if (me != null) avatar(me, tokens.accent),
          if (partner != null)
            Positioned(left: 18, child: avatar(partner, tokens.info)),
        ],
      ),
    );
  }
}

/// What the "Space info" popover shows: who shares the backlog and which part
/// of an entry is shared and which stays with each member.
class _SpaceInfoCard extends StatelessWidget {
  const _SpaceInfoCard({required this.space});

  final Space space;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final partner = space.partnerIsActive ? space.partner!.username : null;

    Widget row(IconData icon, String title, String detail) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(icon, size: 17, color: tokens.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: style.control.copyWith(
                      color: tokens.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: style.caption.copyWith(color: tokens.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: space.infoText,
      child: Padding(
        key: const Key('space-info-text'),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shared Space',
                style: style.section.copyWith(color: tokens.foreground),
              ),
              const SizedBox(height: 2),
              Text(
                partner == null
                    ? 'A co-op backlog for two'
                    : 'Shared with $partner',
                style: style.caption.copyWith(color: tokens.accent),
              ),
              row(
                Icons.layers_outlined,
                'Shared by both',
                'Status and categories',
              ),
              row(
                Icons.person_outline,
                'Stays your own',
                'Rating, playtime and review',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Space info" and "Leave" of the space header.
class SpaceControls extends ConsumerWidget {
  const SpaceControls({required this.space, super.key});

  final Space space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ShelfPopover(
          content: _SpaceInfoCard(space: space),
          builder: (context, menu) => ShelfButton(
            key: const Key('space-info'),
            label: 'Space Info',
            onPressed: () => menu.isOpen ? menu.close() : menu.open(),
          ),
        ),
        ShelfButton(
          key: const Key('space-leave'),
          label: space.waitingForPartner ? 'Cancel Invitation' : 'Leave',
          kind: ShelfButtonKind.danger,
          onPressed: () => unawaited(showLeaveSpaceSheet(context)),
        ),
      ],
    );
  }
}

Future<void> showLeaveSpaceSheet(BuildContext context) {
  return showShelfSheet<void>(context, builder: (_) => const _LeaveSheet());
}

class _LeaveSheet extends ConsumerStatefulWidget {
  const _LeaveSheet();

  @override
  ConsumerState<_LeaveSheet> createState() => _LeaveSheetState();
}

class _LeaveSheetState extends ConsumerState<_LeaveSheet> {
  bool _busy = false;

  Future<void> _leave() async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await ref.read(spaceProvider.notifier).leave();
      if (!mounted) return;
      showShelfToast(context, 'You left the Shared Space');
      navigator.pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showShelfToast(
        context,
        ApiException.from(error, 'Failed to leave the space').message,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShelfSheet(
      title: 'Leave the Shared Space?',
      width: ShelfSheetWidth.compact,
      footer: ShelfSheetFooter(
        cancelLabel: 'Stay',
        onCancel: _busy ? null : () => Navigator.of(context).pop(),
        primary: ShelfButton(
          key: const Key('space-leave-confirm'),
          label: _busy ? 'Leaving...' : 'Leave',
          kind: ShelfButtonKind.danger,
          busy: _busy,
          onPressed: _leave,
        ),
      ),
      child: const Text(leaveWarning),
    );
  }
}

/// Under the header while the space has no active partner: the invitation
/// form, or who the invitation waits for.
class SpaceNotice extends StatelessWidget {
  const SpaceNotice({required this.space, super.key});

  final Space space;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    if (space.partnerIsActive) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: space.needsInvitation
            ? const InviteForm()
            : Text(
                '${space.waitingLine}.',
                key: const Key('space-waiting'),
                style: style.caption.copyWith(color: tokens.muted),
              ),
      ),
    );
  }
}
