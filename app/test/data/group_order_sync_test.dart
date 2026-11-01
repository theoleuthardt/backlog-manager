import 'package:backlog_manager/auth/user_api.dart';
import 'package:backlog_manager/data/group_order_store.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/library/group_order_test.dart' show MemoryGroupOrderStore;

class _Account extends Notifier<SessionUser?> {
  @override
  SessionUser? build() => null;

  void signIn(List<String> order) => state = SessionUser(
    id: 1,
    name: 'theo',
    email: 'theo@example.com',
    setupCompleted: true,
    groupOrder: order,
  );
}

final _account = NotifierProvider<_Account, SessionUser?>(_Account.new);

class _UserApi implements UserApi {
  final updates = <UserUpdate>[];

  @override
  Future<SessionUser> update(UserUpdate changes) async {
    updates.add(changes);
    return const SessionUser(
      id: 1,
      name: 'theo',
      email: 'theo@example.com',
      setupCompleted: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _UserApi api;
  late MemoryGroupOrderStore store;
  late ProviderContainer container;

  setUp(() {
    api = _UserApi();
    store = MemoryGroupOrderStore();
    container = ProviderContainer(
      overrides: [
        sessionUserProvider.overrideWith((ref) => ref.watch(_account)),
        userApiProvider.overrideWithValue(api),
        groupOrderStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('the order of the account replaces the one of the device', () async {
    store.saved = ['status:Old'];
    container.read(groupOrderProvider);
    await settle();

    container.read(_account.notifier).signIn(['status:New', 'status:Other']);
    await settle();

    expect(container.read(groupOrderProvider), ['status:New', 'status:Other']);
    expect(store.saved, ['status:New', 'status:Other']);
  });

  test('an account without an order takes the one of the device', () async {
    store.saved = ['status:Mine'];
    container.read(groupOrderProvider);
    await settle();

    container.read(_account.notifier).signIn(const []);
    await settle();

    expect(container.read(groupOrderProvider), ['status:Mine']);
    expect(api.updates.single.groupOrder, ['status:Mine']);
  });

  test('arranging the groups saves them with the account', () async {
    container.read(groupOrderProvider);
    container.read(_account.notifier).signIn(const []);
    await settle();

    container.read(groupOrderProvider.notifier).arrange(['status:A']);
    await settle();

    expect(api.updates.single.groupOrder, ['status:A']);
    expect(store.saved, ['status:A']);
  });

  test('signed out the order only stays on the device', () async {
    container.read(groupOrderProvider);
    await settle();

    container.read(groupOrderProvider.notifier).arrange(['status:A']);
    await settle();

    expect(api.updates, isEmpty);
    expect(store.saved, ['status:A']);
  });
}
