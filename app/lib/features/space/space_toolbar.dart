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

    Widget avatar(String username, Color color) => DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: tokens.background, width: 2),
      ),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: Text(
            memberInitials(username),
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
    );

    return SizedBox(
      key: const Key('space-avatars'),
      width: partner == null ? 28 : 46,
      height: 28,
      child: Stack(
        children: [
          if (me != null) avatar(me.username, tokens.accent),
          if (partner != null)
            Positioned(left: 18, child: avatar(partner.username, tokens.info)),
        ],
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
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShelfPopover(
          content: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: 260,
              child: Text(
                space.infoText,
                key: const Key('space-info-text'),
                style: style.caption.copyWith(color: tokens.text2),
              ),
            ),
          ),
          builder: (context, menu) => ShelfButton(
            key: const Key('space-info'),
            label: 'Space info',
            onPressed: () => menu.isOpen ? menu.close() : menu.open(),
          ),
        ),
        const SizedBox(width: 8),
        ShelfButton(
          key: const Key('space-leave'),
          label: space.waitingForPartner ? 'Cancel invitation' : 'Leave',
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
      showShelfToast(context, 'You left the shared space');
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
      title: 'Leave the shared space?',
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
