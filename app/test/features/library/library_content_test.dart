import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/domain/filter_tokens.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/library/library_content.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';

BacklogEntry game(
  int id,
  String title, {
  String status = 'Not Started',
  List<String> genre = const [],
  bool owned = false,
}) {
  return BacklogEntry(
    id: id,
    title: title,
    status: status,
    genre: genre,
    owned: owned,
  );
}

class SignedIn extends SessionNotifier {
  @override
  SessionState build() => const SessionSignedIn(
    SessionUser(name: 'Theo', email: 'theo@example.com', setupCompleted: true),
  );
}

void main() {
  late ProviderContainer container;

  setUp(() {
    final api = FakeBacklogApi(
      entries: [
        game(
          1,
          'Hades',
          status: 'Completed',
          genre: ['Roguelike'],
          owned: true,
        ),
        game(2, 'Celeste', status: 'Completed', genre: ['Platformer']),
        game(3, 'Portal 2', status: 'In Progress', genre: ['Puzzle']),
        game(4, 'Outer Wilds', genre: ['Puzzle'], owned: true),
      ],
    );
    api
      ..categoryList = const [
        Category(id: 1, name: 'Co-op nights', color: '#38bdf8'),
      ]
      ..entriesByCategory = {
        1: [game(3, 'Portal 2')],
      };
    container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        backlogApiProvider.overrideWithValue(api),
        sessionProvider.overrideWith(SignedIn.new),
      ],
    );
    addTearDown(container.dispose);
  });

  FiltersNotifier filters() => container.read(filtersProvider.notifier);

  Future<LibraryContent> content() async {
    await container.read(entriesProvider(null).future);
    await container.read(categoriesProvider(null).future);
    await container.read(entryCategoriesProvider(null).future);
    final subscription = container.listen(libraryContentProvider, (_, _) {});
    addTearDown(subscription.close);
    return subscription.read()!;
  }

  List<String> titles(LibraryContent content) => [
    for (final group in content.groups)
      for (final entry in group.entries) entry.title,
  ];

  test('shows every game without filters', () async {
    final library = await content();

    expect(library.shown, 4);
    expect(library.total, 4);
  });

  test('narrows the games by the search text', () async {
    filters().setSearch('PORT');

    final library = await content();

    expect(titles(library), ['Portal 2']);
    expect(library.shown, 1);
    expect(library.total, 4);
  });

  test('narrows the games by list filters and owned only', () async {
    filters()
      ..setList(FilterField.genre, ['Puzzle', 'Roguelike'])
      ..setOwnedOnly(true);

    final library = await content();

    expect(titles(library).toSet(), {'Hades', 'Outer Wilds'});
    expect(library.shown, 2);
  });

  test('narrows the games by category', () async {
    filters().setList(FilterField.category, ['Co-op nights']);

    final library = await content();

    expect(titles(library), ['Portal 2']);
  });

  test('shows only the selected status groups, empty ones too', () async {
    filters().setList(FilterField.status, ['Completed', 'Dropped']);

    final library = await content();

    expect(
      [for (final group in library.groups) group.label],
      ['Completed', 'Dropped'],
    );
    expect(library.shown, 2);
  });
}
