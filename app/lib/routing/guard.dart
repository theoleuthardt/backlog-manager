import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';

/// Where the route guard must send the user for [location], or null to stay.
/// While the session is checked everything shows the loading state, signed-out
/// users go to sign-in, users with an unfinished setup are funnelled into the
/// wizard from every guarded page, and finished users are bounced out of
/// sign-in, the wizard and the loading page.
String? guardRedirect(SessionState session, String location) {
  switch (session) {
    case SessionLoading():
      return location == AppRoutes.loading ? null : AppRoutes.loading;
    case SessionSignedOut():
      return location == AppRoutes.signIn ? null : AppRoutes.signIn;
    case SessionSignedIn(:final user):
      if (!user.setupCompleted) {
        return location == AppRoutes.setup ? null : AppRoutes.setup;
      }
      const leftBehind = {AppRoutes.signIn, AppRoutes.setup, AppRoutes.loading};
      return leftBehind.contains(location) ? AppRoutes.home : null;
  }
}
