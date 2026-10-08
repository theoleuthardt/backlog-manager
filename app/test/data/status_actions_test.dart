import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeBacklogApi api;
  late ProviderContainer container;

  setUp(() {
    api = FakeBacklogApi()
      ..statusList = const [CustomStatus(id: 1, name: 'Replaying')];
    container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [backlogApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
  });

  Future<List<String>> names([int? scope]) async {
    final statuses = await container.read(customStatusesProvider(scope).future);
    return [for (final status in statuses) status.name];
  }

  group('custom status actions', () {
    test('create the status and list it', () async {
      expect(await names(), ['Replaying']);

      final created = await container
          .read(customStatusActionsProvider(null))
          .create('Wishlist');

      expect(created.name, 'Wishlist');
      expect(await names(), ['Replaying', 'Wishlist']);
      expect(api.calls, contains('create-status Wishlist personal'));
    });

    test('delete the status and drop it from the list', () async {
      expect(await names(), ['Replaying']);

      await container.read(customStatusActionsProvider(null)).delete(1);

      expect(await names(), isEmpty);
      expect(api.calls, contains('delete-status 1 personal'));
    });

    test('work on the custom statuses of a shared space', () async {
      await container.read(customStatusActionsProvider(4)).create('Co-op');

      expect(api.calls, contains('create-status Co-op 4'));
      expect(await names(4), ['Replaying', 'Co-op']);
    });

    test('leave the list alone when the request fails', () async {
      expect(await names(), ['Replaying']);
      api.onCreateStatus = (name) async =>
          throw const ApiException('Status already exists');

      await expectLater(
        container.read(customStatusActionsProvider(null)).create('Replaying'),
        throwsA(isA<ApiException>()),
      );

      expect(await names(), ['Replaying']);
    });
  });
}
