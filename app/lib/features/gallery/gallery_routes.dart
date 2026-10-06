import 'package:backlog_manager/features/gallery/gallery_page.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:go_router/go_router.dart';

/// The gallery of the UI kit as a route of the main window; it is only meant
/// for development, so a release build passes `enabled: false`.
List<RouteBase> galleryRoutes({required bool enabled}) {
  if (!enabled) return const [];
  return [
    GoRoute(
      path: AppRoutes.gallery,
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: GalleryPage()),
    ),
  ];
}
