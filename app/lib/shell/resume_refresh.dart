import 'dart:async';

import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/backlog_scope.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The shortest time between two reloads, so that a quick look at another
/// app does not load everything again.
const resumeRefreshInterval = Duration(seconds: 30);

/// Loads the backlog and the account again when the app comes back to the
/// foreground, which shows what was changed on another device meanwhile.
class ResumeRefresh extends ConsumerStatefulWidget {
  const ResumeRefresh({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ResumeRefresh> createState() => _ResumeRefreshState();
}

class _ResumeRefreshState extends ConsumerState<ResumeRefresh> {
  late final AppLifecycleListener _lifecycle;
  DateTime? _last;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refresh() {
    final now = DateTime.now();
    final last = _last;
    if (last != null && now.difference(last) < resumeRefreshInterval) return;
    if (ref.read(sessionUserProvider) == null) return;
    _last = now;
    for (final scope in {null, ref.read(backlogScopeProvider)}) {
      ref
        ..invalidate(entriesProvider(scope))
        ..invalidate(categoriesProvider(scope))
        ..invalidate(entryCategoriesProvider(scope))
        ..invalidate(customStatusesProvider(scope));
    }
    unawaited(
      ref
          .read(authControllerProvider.notifier)
          .refreshUser()
          .catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
