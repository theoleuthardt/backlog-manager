import 'package:backlog_manager/routing/guard.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter_test/flutter_test.dart';

const finished = SessionSignedIn(
  SessionUser(name: 'Theo', email: 'theo@example.com', setupCompleted: true),
);
const unfinished = SessionSignedIn(
  SessionUser(name: 'Theo', email: 'theo@example.com', setupCompleted: false),
);

void main() {
  group('while the session is checked', () {
    test('every page shows the loading state', () {
      expect(
        guardRedirect(const SessionLoading(), AppRoutes.library),
        AppRoutes.loading,
      );
      expect(
        guardRedirect(const SessionLoading(), AppRoutes.signIn),
        AppRoutes.loading,
      );
    });

    test('the loading page stays', () {
      expect(guardRedirect(const SessionLoading(), AppRoutes.loading), isNull);
    });
  });

  group('signed out', () {
    test('sends every page except sign-in to sign-in', () {
      for (final path in [
        AppRoutes.home,
        AppRoutes.library,
        AppRoutes.settings,
        AppRoutes.setup,
        AppRoutes.loading,
      ]) {
        expect(
          guardRedirect(const SessionSignedOut(), path),
          AppRoutes.signIn,
          reason: path,
        );
      }
    });

    test('lets the user stay on sign-in', () {
      expect(guardRedirect(const SessionSignedOut(), AppRoutes.signIn), isNull);
    });
  });

  group('signed in without a finished setup', () {
    test('funnels every guarded page into the wizard', () {
      expect(guardRedirect(unfinished, AppRoutes.home), AppRoutes.setup);
      expect(guardRedirect(unfinished, AppRoutes.settings), AppRoutes.setup);
      expect(guardRedirect(unfinished, AppRoutes.signIn), AppRoutes.setup);
      expect(guardRedirect(unfinished, AppRoutes.loading), AppRoutes.setup);
    });

    test('keeps the user on the wizard', () {
      expect(guardRedirect(unfinished, AppRoutes.setup), isNull);
    });
  });

  group('signed in with a finished setup', () {
    test(
      'sends the user away from sign-in, the wizard and the loading page',
      () {
        expect(guardRedirect(finished, AppRoutes.signIn), AppRoutes.home);
        expect(guardRedirect(finished, AppRoutes.setup), AppRoutes.home);
        expect(guardRedirect(finished, AppRoutes.loading), AppRoutes.home);
      },
    );

    test('leaves every other page alone', () {
      for (final path in [
        AppRoutes.home,
        AppRoutes.library,
        AppRoutes.steam,
        AppRoutes.settings,
        AppRoutes.space,
      ]) {
        expect(guardRedirect(finished, path), isNull, reason: path);
      }
    });
  });
}
