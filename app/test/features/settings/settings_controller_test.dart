import 'dart:async';

import 'package:backlog_manager/auth/auth_api.dart';
import 'package:backlog_manager/auth/token_store.dart';
import 'package:backlog_manager/auth/user_api.dart';
import 'package:backlog_manager/features/settings/settings_controller.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth/fakes.dart';
import '../setup/setup_controller_test.dart' show FakeUserApi;

class SignedIn extends SessionNotifier {
  @override
  SessionState build() => const SessionSignedIn(
    SessionUser(name: 'Theo', email: 't@e.de', setupCompleted: true),
  );
}

void main() {
  late FakeUserApi users;
  late ProviderContainer container;

  setUp(() {
    users = FakeUserApi();
    final auth = FakeAuthApi()
      ..onCurrentUser = () async => const SessionUser(
        name: 'Theo',
        email: 't@e.de',
        setupCompleted: true,
      );
    container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(SignedIn.new),
        userApiProvider.overrideWithValue(users),
        authApiProvider.overrideWithValue(auth),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore('jwt')),
      ],
    );
    addTearDown(container.dispose);
  });

  SettingsController controller() =>
      container.read(settingsControllerProvider.notifier);

  test('starts idle and is saved after a save worked', () async {
    expect(container.read(settingsControllerProvider), SettingsSave.idle);

    final error = await controller().save(const UserUpdate(steamId: '1'));

    expect(error, isNull);
    expect(container.read(settingsControllerProvider), SettingsSave.saved);
  });

  test('keeps the message of the backend when a save fails', () async {
    users.onUpdate = (update) async => throw Exception('boom');

    final error = await controller().save(const UserUpdate(steamId: '1'));

    expect(error, isNotNull);
    expect(container.read(settingsControllerProvider), SettingsSave.failed);
  });

  test('an old save that ends last does not change the status', () async {
    final slowFailure = Completer<void>();
    var call = 0;
    users.onUpdate = (update) async {
      call++;
      if (call == 1) {
        await slowFailure.future;
        throw Exception('late failure');
      }
      return const SessionUser(
        name: 'Theo',
        email: 't@e.de',
        setupCompleted: true,
      );
    };

    final first = controller().save(const UserUpdate(steamId: '1'));
    await controller().save(const UserUpdate(steamId: '2'));
    expect(container.read(settingsControllerProvider), SettingsSave.saved);
    slowFailure.complete();
    final error = await first;

    expect(error, isNotNull);
    expect(container.read(settingsControllerProvider), SettingsSave.saved);
  });

  test('an old save that ends first does not claim it is saved', () async {
    final slowSuccess = Completer<void>();
    var call = 0;
    users.onUpdate = (update) async {
      call++;
      if (call == 2) {
        await slowSuccess.future;
      }
      return const SessionUser(
        name: 'Theo',
        email: 't@e.de',
        setupCompleted: true,
      );
    };

    unawaited(controller().save(const UserUpdate(steamId: '1')));
    final second = controller().save(const UserUpdate(steamId: '2'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(settingsControllerProvider), SettingsSave.saving);
    slowSuccess.complete();
    await second;

    expect(container.read(settingsControllerProvider), SettingsSave.saved);
  });
}
