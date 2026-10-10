import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/steam_sync.dart';
import 'package:backlog_manager/features/steam/steam_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The icon button of the library toolbar that syncs playtimes from Steam.
/// While it runs the icon spins and, once the total is known, a ring around
/// it fills with the progress; the tooltip names the exact count.
class SteamSyncButton extends ConsumerWidget {
  const SteamSyncButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final sync = ref.watch(playtimeSyncProvider);
    final tooltip = playtimeSyncTooltip(
      sync.processed,
      sync.total,
      running: sync.running,
    );

    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (sync.running && sync.total != null)
            SizedBox(
              key: const Key('steam-sync-ring'),
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                value: sync.fraction,
                strokeWidth: 2.5,
                color: tokens.accent,
                backgroundColor: Colors.transparent,
              ),
            ),
          ShelfIconButton(
            key: const Key('steam-sync-button'),
            icon: Icons.sync,
            tooltip: tooltip,
            onPressed: sync.running
                ? null
                : () async {
                    final message = await ref
                        .read(playtimeSyncProvider.notifier)
                        .run();
                    if (message != null && context.mounted) {
                      showShelfToast(context, message);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
