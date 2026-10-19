import 'dart:async';

import 'package:backlog_manager/data/update_channel.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/design/widgets/segmented.dart';
import 'package:backlog_manager/domain/app_update.dart';
import 'package:backlog_manager/features/updates/app_update_state.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The "App Updates" group of the About tab: a manual check and its result.
/// A newer release shows its notes and, where the install can update itself,
/// a button that downloads and checks it and then restarts into it; elsewhere
/// a button to its page in the browser. When the newest release of the
/// channel is older than the installed version (Stable while a pre-release is
/// installed) the same two buttons offer to go back to it.
class AppUpdateGroup extends ConsumerWidget {
  const AppUpdateGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final state = ref.watch(appUpdateProvider);
    final release = state.release;
    final checking = state.check == UpdateCheck.checking;
    final notifier = ref.read(appUpdateProvider.notifier);
    final inPlace = release != null && notifier.canInstallInPlace;
    final installing =
        state.install == UpdateInstall.downloading ||
        state.install == UpdateInstall.verifying;

    Widget note(String text, {Color? color, Key? key}) => Text(
      text,
      key: key,
      style: style.control.copyWith(color: color ?? tokens.muted),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: ShelfFormGroup(
        title: 'App Updates',
        description:
            'Backlog Manager checks for a new version when it starts. You can '
            'also check manually.',
        rows: [
          ShelfFormRow(
            label: 'Update Channel',
            description:
                'Stable gets the normal releases. Preview also gets the '
                'pre-releases, which come earlier and can have bugs. Kept on '
                'this device.',
            control: ShelfSegmented<UpdateChannel>(
              segments: [
                for (final channel in UpdateChannel.values)
                  ShelfSegment(value: channel, label: channel.label),
              ],
              value: ref.watch(updateChannelProvider),
              onChanged: (channel) {
                ref.read(updateChannelProvider.notifier).select(channel);
                unawaited(notifier.check());
              },
            ),
          ),
          ShelfFormRow(
            label: 'Updates',
            control: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                switch (state.install) {
                  UpdateInstall.downloading => SizedBox(
                    width: 200,
                    child: ShelfProgressBar(
                      key: const Key('update-progress'),
                      value: state.progress ?? 0,
                    ),
                  ),
                  UpdateInstall.verifying => note('Checking the download...'),
                  UpdateInstall.ready => note(
                    'Version ${release?.version} is ready to install.',
                  ),
                  UpdateInstall.installing => note('Restarting...'),
                  UpdateInstall.failed => note(
                    state.installError ?? 'The update failed.',
                    color: tokens.danger,
                    key: const Key('update-error'),
                  ),
                  UpdateInstall.none => switch (state.check) {
                    UpdateCheck.upToDate => note(
                      'You are on the latest version.',
                    ),
                    UpdateCheck.failed => note(
                      'The update check failed. Try again later.',
                      color: tokens.danger,
                    ),
                    UpdateCheck.available when release != null => note(
                      'Version ${release.version} is available.',
                    ),
                    UpdateCheck.older when release != null => note(
                      'You are ahead of the newest '
                      '${ref.watch(updateChannelProvider).label} release '
                      '(${release.version}).',
                    ),
                    _ => const SizedBox.shrink(),
                  },
                },
                const SizedBox(width: 12),
                if (state.install == UpdateInstall.ready)
                  ShelfButton(
                    key: const Key('restart-update'),
                    label: 'Restart to Update',
                    kind: ShelfButtonKind.primary,
                    onPressed: notifier.restart,
                  )
                else if (inPlace &&
                    state.check == UpdateCheck.available &&
                    !installing &&
                    state.install != UpdateInstall.installing)
                  ShelfButton(
                    key: const Key('install-update'),
                    label: state.install == UpdateInstall.failed
                        ? 'Try Again'
                        : 'Install Update',
                    kind: ShelfButtonKind.primary,
                    onPressed: notifier.install,
                  )
                else if (inPlace &&
                    state.check == UpdateCheck.older &&
                    !installing &&
                    state.install != UpdateInstall.installing)
                  ShelfButton(
                    key: const Key('downgrade-update'),
                    label: state.install == UpdateInstall.failed
                        ? 'Try Again'
                        : 'Switch to ${release.version}',
                    onPressed: notifier.install,
                  )
                else if (release != null &&
                    (state.check == UpdateCheck.available ||
                        state.check == UpdateCheck.older) &&
                    !installing)
                  ShelfButton(
                    key: const Key('view-release'),
                    label: state.check == UpdateCheck.older
                        ? 'View ${release.version}'
                        : 'View Release',
                    kind: ShelfButtonKind.primary,
                    onPressed: () =>
                        ref.read(urlOpenerProvider)(release.pageUrl),
                  )
                else if (!installing)
                  ShelfButton(
                    key: const Key('check-for-updates'),
                    label: checking ? 'Checking...' : 'Check for updates',
                    onPressed: checking ? null : notifier.check,
                  ),
              ],
            ),
          ),
          if (release != null &&
              state.check == UpdateCheck.available &&
              release.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                release.notes,
                style: style.control.copyWith(color: tokens.text2),
              ),
            ),
        ],
      ),
    );
  }
}
