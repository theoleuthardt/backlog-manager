import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/features/updates/app_update_state.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The "App Updates" group of the About tab: a manual check and its result.
/// A newer release shows its notes and a button to its page in the browser.
class AppUpdateGroup extends ConsumerWidget {
  const AppUpdateGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final state = ref.watch(appUpdateProvider);
    final release = state.release;
    final checking = state.check == UpdateCheck.checking;

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
            label: 'Updates',
            control: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                switch (state.check) {
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
                  _ => const SizedBox.shrink(),
                },
                const SizedBox(width: 12),
                if (release != null && state.check == UpdateCheck.available)
                  ShelfButton(
                    key: const Key('view-release'),
                    label: 'View release',
                    kind: ShelfButtonKind.primary,
                    onPressed: () =>
                        ref.read(urlOpenerProvider)(release.pageUrl),
                  )
                else
                  ShelfButton(
                    key: const Key('check-for-updates'),
                    label: checking ? 'Checking...' : 'Check for updates',
                    onPressed: checking
                        ? null
                        : ref.read(appUpdateProvider.notifier).check,
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
