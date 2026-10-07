import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/auth/auth_api.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/auth/token_store.dart';
import 'package:backlog_manager/auth/user_api.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/features/setup/setup_controller.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth/fakes.dart';

class FakeUserApi implements UserApi {
  final updates = <UserUpdate>[];
  Future<SessionUser> Function(UserUpdate update)? onUpdate;

  @override
  Future<SessionUser> update(UserUpdate update) {
    updates.add(update);
    return onUpdate?.call(update) ??
        Future.value(
          SessionUser(
            name: 'Theo',
            email: 't@e.de',
            setupCompleted: update.setupCompleted ?? false,
          ),
        );
  }
}

void main() {
  late FakeUserApi users;
  late FakeAuthApi auth;
  late ProviderContainer container;

  setUp(() {
    users = FakeUserApi();
    auth = FakeAuthApi()
      ..onCurrentUser = () async => const SessionUser(
        name: 'Theo',
        email: 't@e.de',
        setupCompleted: true,
      );
    container = ProviderContainer(
      overrides: [
        userApiProvider.overrideWithValue(users),
        authApiProvider.overrideWithValue(auth),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore('jwt')),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(sessionProvider.notifier)
        .signIn(
          const SessionUser(
            name: 'Theo',
            email: 't@e.de',
            setupCompleted: false,
          ),
        );
  });

  SetupController controller() =>
      container.read(setupControllerProvider.notifier);
  SetupState state() => container.read(setupControllerProvider);

  test('starts on the first of five steps with the defaults', () {
    expect(state().step, 0);
    expect(setupSteps, ['Theme', 'Sorting', 'Steam', 'IGDB', 'Done']);
    expect(state().defaultSort, 'status');
    expect(state().isLastStep, isFalse);
  });

  test('forgets the wizard values when the session changes', () {
    controller().setDefaultSort('rating');
    expect(state().defaultSort, 'rating');

    container.read(sessionGenerationProvider.notifier).bump();

    expect(state().defaultSort, 'status');
  });

  group('next', () {
    test('saves the theme of the first step and moves on', () async {
      container.read(themeIdProvider.notifier).select('light');

      await controller().next();

      expect(users.updates.single.theme, 'light');
      expect(state().step, 1);
    });

    test('saves the default sort of the second step', () async {
      await controller().next();
      controller().setDefaultSort('playtime');

      await controller().next();

      expect(users.updates.last.defaultSort, 'playtime');
      expect(users.updates.last.theme, isNull);
      expect(state().step, 2);
    });

    test(
      'saves the Steam values only when they were entered, trimmed',
      () async {
        await controller().next();
        await controller().next();
        controller()
          ..setSteamId('  76561197960287930 ')
          ..setSteamApiKey(' key ');

        await controller().next();

        expect(users.updates.last.steamId, '76561197960287930');
        expect(users.updates.last.steamApiKey, 'key');
        expect(state().step, 3);
      },
    );

    test('sends nothing for an empty Steam step', () async {
      await controller().next();
      await controller().next();
      final before = users.updates.length;

      await controller().next();

      expect(users.updates.length, before);
      expect(state().step, 3);
    });

    test(
      'refuses a single IGDB field with the message of the web client',
      () async {
        for (var i = 0; i < 3; i++) {
          await controller().next();
        }
        final before = users.updates.length;
        controller().setIgdbClientId('client');

        await controller().next();

        expect(
          state().error,
          'Enter both the IGDB Client ID and Client Secret, or neither',
        );
        expect(state().step, 3);
        expect(users.updates.length, before);
      },
    );

    test('saves both IGDB fields together', () async {
      for (var i = 0; i < 3; i++) {
        await controller().next();
      }
      controller()
        ..setIgdbClientId(' client ')
        ..setIgdbClientSecret(' secret ');

      await controller().next();

      expect(users.updates.last.igdbClientId, 'client');
      expect(users.updates.last.igdbClientSecret, 'secret');
      expect(state().step, 4);
      expect(state().isLastStep, isTrue);
    });

    test('lets the IGDB step pass without credentials', () async {
      for (var i = 0; i < 4; i++) {
        await controller().next();
      }

      expect(state().step, 4);
    });

    test('stays on the step with the error when saving fails', () async {
      users.onUpdate = (_) async =>
          throw const ApiException('Server unavailable');

      await controller().next();

      expect(state().step, 0);
      expect(state().error, 'Server unavailable');
      expect(state().saving, isFalse);
    });

    test('is saving while the request runs', () async {
      final seen = <bool>[];
      container.listen(
        setupControllerProvider,
        (_, next) => seen.add(next.saving),
      );

      await controller().next();

      expect(seen, contains(true));
      expect(seen.last, isFalse);
    });

    test('clears the error with the next attempt', () async {
      users.onUpdate = (_) async =>
          throw const ApiException('Server unavailable');
      await controller().next();
      users.onUpdate = null;

      await controller().next();

      expect(state().error, isNull);
      expect(state().step, 1);
    });
  });

  group('back', () {
    test('goes one step back and not before the first', () async {
      await controller().next();

      controller().back();
      expect(state().step, 0);
      controller().back();
      expect(state().step, 0);
    });

    test('keeps what was typed', () async {
      await controller().next();
      controller().setDefaultSort('genre');
      controller().back();
      await controller().next();

      expect(state().defaultSort, 'genre');
    });
  });

  group('finishing', () {
    test(
      'marks the setup as completed and signs the completed user in',
      () async {
        await controller().finish();

        expect(users.updates.single.setupCompleted, isTrue);
        expect(
          (container.read(
            sessionProvider,
          ) as SessionSignedIn).user.setupCompleted,
          isTrue,
        );
      },
    );

    test('skipping does the same from any step', () async {
      await controller().next();

      await controller().skip();

      expect(users.updates.last.setupCompleted, isTrue);
      expect(
        (container.read(
          sessionProvider,
        ) as SessionSignedIn).user.setupCompleted,
        isTrue,
      );
    });

    test('reports a failed refresh of the user instead of throwing', () async {
      auth.onCurrentUser = () async => throw const ApiException('Offline');

      await controller().finish();

      expect(users.updates.single.setupCompleted, isTrue);
      expect(state().error, 'Offline');
    });

    test('stays on the wizard with an error when the save fails', () async {
      users.onUpdate = (_) async =>
          throw const ApiException('Server unavailable');

      await controller().finish();

      expect(state().error, 'Server unavailable');
      expect(
        (container.read(
          sessionProvider,
        ) as SessionSignedIn).user.setupCompleted,
        isFalse,
      );
    });
  });
}
