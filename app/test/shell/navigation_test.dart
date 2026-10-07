import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groups the navigation like the design', () {
    expect(navigationSections.map((s) => s.label), [
      'Backlog',
      'Add',
      'Personalise',
    ]);
    expect(navigationSections[0].items.map((i) => i.label), [
      'Home',
      'Library',
      'Shared space',
    ]);
    expect(navigationSections[1].items.map((i) => i.label), [
      'Add game',
      'Steam sync',
      'Import CSV',
      'Export CSV',
    ]);
    expect(navigationSections[2].items.map((i) => i.label), [
      'Appearance',
      'Settings',
    ]);
  });

  test(
    'sends every item to a route of the route table, except adding a game',
    () {
      final byLabel = {
        for (final section in navigationSections)
          for (final item in section.items) item.label: item,
      };

      expect(byLabel['Home']!.route, AppRoutes.home);
      expect(byLabel['Library']!.route, AppRoutes.library);
      expect(byLabel['Shared space']!.route, AppRoutes.space);
      expect(byLabel['Steam sync']!.route, AppRoutes.steam);
      expect(byLabel['Import CSV']!.route, AppRoutes.import);
      expect(byLabel['Export CSV']!.route, AppRoutes.export);
      expect(byLabel['Appearance']!.route, AppRoutes.appearance);
      expect(byLabel['Settings']!.route, AppRoutes.settings);
      expect(byLabel['Add game']!.route, isNull);
      expect(byLabel['Add game']!.action, NavigationAction.addGame);
    },
  );

  test('gives every item an id that is unique', () {
    final ids = [
      for (final section in navigationSections)
        for (final item in section.items) item.id,
    ];

    expect(ids.toSet().length, ids.length);
  });

  test('marks an item as active for its own route only', () {
    final library = navigationSections[0].items[1];

    expect(library.isActiveFor(AppRoutes.library), isTrue);
    expect(library.isActiveFor(AppRoutes.home), isFalse);
    expect(library.isActiveFor('${AppRoutes.library}/'), isTrue);
  });

  test(
    'does not mark Home as active for every path that starts with a slash',
    () {
      final home = navigationSections[0].items[0];

      expect(home.isActiveFor(AppRoutes.home), isTrue);
      expect(home.isActiveFor(AppRoutes.library), isFalse);
    },
  );
}
