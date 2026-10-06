import 'package:backlog_manager/design/glass.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/shell/app_version.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The 28 px bar at the bottom: the counts of the screen on the left, the sync
/// state and the app version on the right.
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final status = ref.watch(shellStatusProvider);
    final version = ref.watch(appVersionProvider).value;
    final style = Theme.of(context)
        .extension<ShelfTextStyles>()!
        .label
        .copyWith(color: tokens.muted, fontWeight: FontWeight.w400);

    return SizedBox(
      key: const Key('status-bar'),
      height: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tokens.borderSubtle)),
        ),
        child: GlassSurface(
          opacity: 0.42,
          blur: 10,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DefaultTextStyle(
              style: style,
              child: Row(
                children: [
                  if (status.counts != null) Text(status.counts!),
                  const Spacer(),
                  if (status.sync != null) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: tokens.success, blurRadius: 8),
                        ],
                      ),
                      child: const SizedBox(width: 6, height: 6),
                    ),
                    const SizedBox(width: 8),
                    Text(status.sync!),
                    const SizedBox(width: 16),
                  ],
                  if (version != null) Text(version),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
