import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/domain/inspector_logic.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/space.dart';
import 'package:flutter/material.dart';

/// Below a cover in the shared space: the hours of both members, each with
/// their initials and a bar of how far they are with the game.
class MemberProgress extends StatelessWidget {
  const MemberProgress({
    required this.entry,
    required this.me,
    required this.partner,
    super.key,
  });

  final BacklogEntry entry;
  final String me;
  final String? partner;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return Column(
      key: const Key('member-progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _line(
          context,
          initials: memberInitials(me),
          color: tokens.accent,
          hours: entry.playtime,
        ),
        if (partner != null) ...[
          const SizedBox(height: 6),
          _line(
            context,
            initials: memberInitials(partner!),
            color: tokens.info,
            hours: entry.partnerPlaytime,
          ),
        ],
      ],
    );
  }

  Widget _line(
    BuildContext context, {
    required String initials,
    required Color color,
    required double? hours,
  }) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Row(
      children: [
        SizedBox(
          width: 26,
          child: Text(
            initials,
            style: style.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: ShelfProgressBar(
            value: beatFraction(entry.mainTime, hours),
            height: 4,
            color: color == tokens.info ? color : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          memberHoursLabel(hours),
          style: style.caption.copyWith(color: tokens.muted),
        ),
      ],
    );
  }
}
