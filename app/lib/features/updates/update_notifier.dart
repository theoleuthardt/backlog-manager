import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/features/updates/app_update_state.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows [child]; when the app starts it checks quietly for a newer release
/// (release builds only) and announces one with a toast that stays until it
/// is closed or another toast replaces it. The announcement is made once per
/// session; the toast opens the release page.
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
    ref.read(appUpdateProvider.notifier).markAnnounced();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showShelfToast(
        context,
        'Backlog Manager ${release.version} is available',
        actionLabel: 'View release',
        onAction: () => ref.read(urlOpenerProvider)(release.pageUrl),
        duration: const Duration(days: 1),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appUpdateProvider, (_, next) => _announce(next));
    return widget.child;
  }
}
