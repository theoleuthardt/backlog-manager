import 'package:backlog_manager/features/gallery/gallery_routes.dart';
import 'package:backlog_manager/routing/guard.dart';
import 'package:backlog_manager/routing/history.dart';
import 'package:backlog_manager/routing/pages.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/app_shell.dart';
import 'package:backlog_manager/shell/navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _mainPages = [
  AppRoutes.home,
  AppRoutes.library,
  AppRoutes.steam,
  AppRoutes.import,
  AppRoutes.export,
  AppRoutes.creationTool,
  AppRoutes.appearance,
  AppRoutes.space,
];

GoRoute _page(String path, Widget Function(String title) page) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) =>
        NoTransitionPage(child: page(pageTitle(path))),
  );
}

GoRoute _fullWindow(String path, Key pageKey) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => NoTransitionPage(
      child: FullWindowFrame(
        location: path,
        child: PlaceholderPage(key: pageKey, title: pageTitle(path)),
      ),
    ),
  );
}

/// The router of the app. Main pages share the sidebar shell; sign-in, the
/// wizard, the loading state and settings are full-window pages with the same
/// title bar (separate native windows would need a second Flutter engine per
/// window, which is not worth it before these screens exist). The guard sends
/// users where their session needs them, and the history behind the back and
/// forward buttons is kept here.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (previous, next) {
    Future.microtask(() {
      if (ref.mounted) ref.read(navigationHistoryProvider.notifier).reset();
    });
    refresh.value++;
  });

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) =>
        guardRedirect(ref.read(sessionProvider), state.uri.path),
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          for (final path in _mainPages)
            _page(path, (title) => PlaceholderPage(title: title)),
          ...galleryRoutes(enabled: kDebugMode),
        ],
      ),
      _fullWindow(AppRoutes.settings, const Key('page-settings')),
      _fullWindow(AppRoutes.signIn, const Key('page-sign-in')),
      _fullWindow(AppRoutes.setup, const Key('page-setup')),
      _fullWindow(AppRoutes.loading, const Key('page-loading')),
    ],
  );

  void recordVisit() {
    final location = router.routerDelegate.currentConfiguration.uri.path;
    Future.microtask(() {
      if (ref.mounted) {
        ref.read(navigationHistoryProvider.notifier).visit(location);
      }
    });
  }

  router.routerDelegate.addListener(recordVisit);
  ref.onDispose(() {
    router.routerDelegate.removeListener(recordVisit);
    router.dispose();
    refresh.dispose();
  });
  return router;
});
