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
    api = FakeBacklogApi(
      entries: [
        const BacklogEntry(id: 1, title: 'Portal 2'),
        const BacklogEntry(id: 2, title: 'Celeste'),
      ],
    )..categoryList = const [Category(id: 1, name: 'Story', color: '#38bdf8')];
    container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [backlogApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
  });

  CategoryActions actions([int? scope]) =>
      container.read(categoryActionsProvider(scope));
  Future<List<String>> names([int? scope]) async => [
    for (final c in await container.read(categoriesProvider(scope).future))
      c.name,
  ];
  Future<Map<int, List<String>>> assigned([int? scope]) async {
    final byEntry = await container.read(entryCategoriesProvider(scope).future);
    return {
      for (final item in byEntry.entries)
        item.key: [for (final c in item.value) c.name],
    };
  }

  group('category actions', () {
    test('create a category and list it', () async {
      expect(await names(), ['Story']);

      final created = await actions().create('Co-op nights', '#4ade80');

      expect(created.name, 'Co-op nights');
      expect(await names(), ['Story', 'Co-op nights']);
      expect(
        api.calls,
        contains('create-category Co-op nights #4ade80 personal'),
      );
    });

    test('rename and recolour a category', () async {
      expect(await names(), ['Story']);

      await actions().update(1, name: 'Plot');
      await actions().update(1, color: '#f87171');

      final category = (await container.read(categoriesProvider(null).future))
          .single;
      expect(category.name, 'Plot');
      expect(category.color, '#f87171');
    });

    test('assign and remove a category of a game', () async {
      expect(await assigned(), isEmpty);

      await actions().setAssigned(1, 1, assigned: true);
      expect(await assigned(), {
        1: ['Story'],
      });

      await actions().setAssigned(1, 1, assigned: false);
      expect(await assigned(), isEmpty);
    });

    test('delete a category and drop it from every game', () async {
      await actions().setAssigned(2, 1, assigned: true);
      expect(await assigned(), {
        2: ['Story'],
      });

      await actions().delete(1);

      expect(await names(), isEmpty);
      expect(await assigned(), isEmpty);
    });

    test('work on the categories of a shared space', () async {
      await actions(4).create('Co-op', '#38bdf8');

      expect(api.calls, contains('create-category Co-op #38bdf8 4'));
    });

    test('leave the list alone when a request fails', () async {
      expect(await names(), ['Story']);
      api.onCreateCategory = (name) async =>
          throw const ApiException('Category already exists');

      await expectLater(
        actions().create('Story', '#38bdf8'),
        throwsA(isA<ApiException>()),
      );

      expect(await names(), ['Story']);
    });
  });
}
