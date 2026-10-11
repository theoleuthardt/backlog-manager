import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/features/updates/app_update_state.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows [child]; when the app starts it checks quietly for a newer release
/// (release builds only) and announces one with a toast that stays until it
/// is closed or another toast replaces it. The announcement is made once per
/// session. Where the install can update itself the toast installs the update
/// and then offers the restart; elsewhere it opens the release page.
class UpdateNotifier extends ConsumerStatefulWidget {
  const UpdateNotifier({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<UpdateNotifier> createState() => _UpdateNotifierState();
}

class _UpdateNotifierState extends ConsumerState<UpdateNotifier> {
  @override
  void initState() {
    super.initState();
    if (!ref.read(automaticUpdateCheckProvider)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appUpdateProvider.notifier).check(quiet: true);
      }
    });
  }

  void _announce(AppUpdateState state) {
    final release = state.release;
    if (state.check != UpdateCheck.available ||
        release == null ||
        state.announced) {
      return;
    }
    final notifier = ref.read(appUpdateProvider.notifier)..markAnnounced();
    final inPlace = notifier.canInstallInPlace;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showShelfToast(
        context,
        'Backlog Manager ${release.version} is available',
        actionLabel: inPlace ? 'Install Update' : 'View Release',
        onAction: inPlace
            ? notifier.install
            : () => ref.read(urlOpenerProvider)(release.pageUrl),
        duration: const Duration(days: 1),
      );
    });
  }

  void _installProgress(AppUpdateState? before, AppUpdateState next) {
    if (before?.install == next.install) return;
    final notifier = ref.read(appUpdateProvider.notifier);
    switch (next.install) {
      case UpdateInstall.ready:
        showShelfToast(
          context,
          'Backlog Manager ${next.release?.version} is ready to install',
          actionLabel: 'Restart to Update',
          onAction: notifier.restart,
          duration: const Duration(days: 1),
        );
      case UpdateInstall.failed:
        showShelfToast(context, next.installError ?? 'The update failed.');
      case UpdateInstall.none:
      case UpdateInstall.downloading:
      case UpdateInstall.verifying:
      case UpdateInstall.installing:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appUpdateProvider, (before, next) {
      _announce(next);
      _installProgress(before, next);
    });
    return widget.child;
  }
}
