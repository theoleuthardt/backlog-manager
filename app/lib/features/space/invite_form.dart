import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/space.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The username of the partner to invite and the button that sends the
/// invitation.
class InviteForm extends ConsumerStatefulWidget {
  const InviteForm({super.key});

  @override
  ConsumerState<InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends ConsumerState<InviteForm> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final name = inviteName(_controller.text);
    if (name == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(spaceProvider.notifier).invite(name);
      if (!mounted) return;
      _controller.clear();
      showShelfToast(context, 'Invitation sent to $name');
    } on Object catch (error) {
      if (mounted) {
        showShelfToast(
          context,
          ApiException.from(error, 'Failed to send invitation').message,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 240,
          height: ShelfHeight.input,
          child: TextField(
            key: const Key('space-invite-name'),
            controller: _controller,
            style: style.fieldText,
            textAlignVertical: TextAlignVertical.center,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => unawaited(_send()),
            decoration: const InputDecoration(
              hintText: 'Username of your co-op partner',
            ),
          ),
        ),
        const SizedBox(width: 8),
        ShelfButton(
          key: const Key('space-invite-send'),
          label: 'Invite',
          kind: ShelfButtonKind.primary,
          busy: _busy,
          onPressed: inviteName(_controller.text) == null
              ? null
              : () => unawaited(_send()),
        ),
      ],
    );
  }
}
