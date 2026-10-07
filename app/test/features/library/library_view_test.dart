import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/domain/sort_entries.dart';
import 'package:backlog_manager/features/library/library_view.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class SignedIn extends SessionNotifier {
  SignedIn(this.defaultSort);

  final String defaultSort;

  @override
  SessionState build() => SessionSignedIn(
    SessionUser(
      name: 'Theo',
      email: 'theo@example.com',
      setupCompleted: true,
      defaultSort: defaultSort,
    ),
  );
}

ProviderContainer containerFor(String defaultSort) {
  final container = ProviderContainer(
    overrides: [sessionProvider.overrideWith(() => SignedIn(defaultSort))],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('the starting point', () {
    test('is the default sort of the account with its default direction', () {
      final view = containerFor('playtime').read(libraryViewProvider);

      expect(view.sortBy, SortOption.playtime);
      expect(view.direction, SortDirection.desc);
      expect(view.layout, LibraryLayout.grid);
    });

    test('starts again from the account after the session changes', () {
      final container = containerFor('playtime');
      container.read(libraryViewProvider.notifier)
        ..setSort(SortOption.genre)
        ..toggleCollapsed('status:Playing');
      expect(container.read(libraryViewProvider).sortBy, SortOption.genre);

      container.read(sessionGenerationProvider.notifier).bump();

      final view = container.read(libraryViewProvider);
      expect(view.sortBy, SortOption.playtime);
      expect(view.collapsed, isEmpty);
    });

    test('falls back to status for an unknown identifier', () {
      final view = containerFor('whatever').read(libraryViewProvider);

      expect(view.sortBy, SortOption.status);
      expect(view.direction, SortDirection.asc);
    });
  });

  group('sorting', () {
    test('changing the option resets the direction to its default', () {
      final container = containerFor('status');
      final notifier = container.read(libraryViewProvider.notifier);

      notifier.toggleDirection();
      expect(container.read(libraryViewProvider).direction, SortDirection.desc);

      notifier.setSort(SortOption.genre);
      expect(container.read(libraryViewProvider).sortBy, SortOption.genre);
      expect(container.read(libraryViewProvider).direction, SortDirection.asc);

      notifier.setSort(SortOption.reviewStars);
      expect(container.read(libraryViewProvider).direction, SortDirection.desc);
    });

    test('toggles the direction both ways', () {
      final container = containerFor('status');
      final notifier = container.read(libraryViewProvider.notifier);

      notifier.toggleDirection();
      notifier.toggleDirection();

      expect(container.read(libraryViewProvider).direction, SortDirection.asc);
    });
  });

  test('switches the layout', () {
    final container = containerFor('status');

    container.read(libraryViewProvider.notifier).setLayout(LibraryLayout.list);

    expect(container.read(libraryViewProvider).layout, LibraryLayout.list);
  });

  group('groups', () {
    test('collapse and expand', () {
      final container = containerFor('status');
      final notifier = container.read(libraryViewProvider.notifier);

      notifier.toggleCollapsed('status:Completed');
      expect(
        container.read(libraryViewProvider).isCollapsed('status:Completed'),
        isTrue,
      );
      expect(
        container.read(libraryViewProvider).isCollapsed('status:Dropped'),
        isFalse,
      );

      notifier.toggleCollapsed('status:Completed');
      expect(
        container.read(libraryViewProvider).isCollapsed('status:Completed'),
        isFalse,
      );
    });

    test('keep the collapsed state when the sort changes and comes back', () {
      final container = containerFor('status');
      final notifier = container.read(libraryViewProvider.notifier);

      notifier.toggleCollapsed('status:Completed');
      notifier.setSort(SortOption.genre);
      notifier.setSort(SortOption.status);

      expect(
        container.read(libraryViewProvider).isCollapsed('status:Completed'),
        isTrue,
      );
    });

    test('show 60 covers and 60 more with each "Show more"', () {
      final container = containerFor('status');
      final notifier = container.read(libraryViewProvider.notifier);

      expect(
        container.read(libraryViewProvider).visibleIn('status:Dropped'),
        60,
      );

      notifier.showMore('status:Dropped');
      notifier.showMore('status:Dropped');

      expect(
        container.read(libraryViewProvider).visibleIn('status:Dropped'),
        180,
      );
      expect(
        container.read(libraryViewProvider).visibleIn('status:Completed'),
        60,
      );
    });
  });
}
