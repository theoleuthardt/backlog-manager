import 'dart:async';

import 'package:backlog_manager/design/background_motion.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _seenKey = 'blm-search-hint-seen';

/// Whether the first-run hint of the search may show; tests switch it off so
/// that no toast waits in their overlay.
bool searchHintEnabled = true;

final searchHintStoreProvider = Provider<BackgroundMotionStore>(
  (ref) => const PreferencesBackgroundMotionStore(_seenKey),
);

/// Whether the hint of the search was shown on this device, kept on the device
/// so that it comes once and never again.
class SearchHintSeenNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      await ref.read(searchHintStoreProvider).read() ?? false;

  void markSeen() {
    state = const AsyncData(true);
    unawaited(ref.read(searchHintStoreProvider).write(enabled: true));
  }
}

final searchHintSeenProvider =
    AsyncNotifierProvider<SearchHintSeenNotifier, bool>(
      SearchHintSeenNotifier.new,
    );

/// Shows [child] and, the first time the library is open on this device, a
/// toast that tells how to search: the shortcut of the command palette, which
/// finds games and runs commands, and `/` for the field of the title bar,
/// which filters the library.
class SearchHintPrompt extends ConsumerStatefulWidget {
  const SearchHintPrompt({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  @override
  ConsumerState<SearchHintPrompt> createState() => _SearchHintPromptState();
}

class _SearchHintPromptState extends ConsumerState<SearchHintPrompt> {
  var _shown = false;

  void _maybeShow() {
    if (_shown ||
        !searchHintEnabled ||
        widget.location != AppRoutes.library ||
        ref.read(searchHintSeenProvider).value != false) {
      return;
    }
    _shown = true;
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.location != AppRoutes.library) {
        _shown = false;
        return;
      }
      showShelfToast(
        context,
        'Press ${isMac ? '⌘K' : 'Ctrl+K'} to search games and run commands, '
        'or / to filter your library.',
        actionLabel: 'Got It',
        onAction: () {},
        duration: const Duration(seconds: 15),
      );
      ref.read(searchHintSeenProvider.notifier).markSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(searchHintSeenProvider, (_, _) => _maybeShow());
    _maybeShow();
    return widget.child;
  }
}
