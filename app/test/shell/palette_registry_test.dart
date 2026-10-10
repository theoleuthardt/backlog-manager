import 'package:backlog_manager/shell/palette_registry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PaletteAction action(String id, String label, {PaletteShortcut? shortcut}) =>
    PaletteAction(id: id, label: label, shortcut: shortcut, run: () {});

void main() {
  group('the registry', () {
    test('keeps the actions in the order they were registered', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final registry = container.read(paletteRegistryProvider.notifier);

      registry
        ..register(action('a', 'Alpha'))
        ..register(action('b', 'Beta'));

      expect(container.read(paletteRegistryProvider).map((a) => a.id), [
        'a',
        'b',
      ]);
    });

    test('replaces an action with the same id in place', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final registry = container.read(paletteRegistryProvider.notifier)
        ..register(action('a', 'Alpha'))
        ..register(action('b', 'Beta'))
        ..register(action('a', 'Alpha again'));

      expect(container.read(paletteRegistryProvider).map((a) => a.label), [
        'Alpha again',
        'Beta',
      ]);
      expect(registry, isNotNull);
    });

    test('removes an action by id', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(paletteRegistryProvider.notifier)
        ..register(action('a', 'Alpha'))
        ..register(action('b', 'Beta'))
        ..unregister('a');

      expect(container.read(paletteRegistryProvider).map((a) => a.id), ['b']);
    });
  });

  group('actionsMatching', () {
    final actions = [
      action('add', 'Add game'),
      action('sync', 'Sync Steam playtimes'),
      action('settings', 'Open settings'),
    ];

    test('lists every action for an empty query, in registration order', () {
      expect(actionsMatching(actions, '').map((a) => a.id), [
        'add',
        'sync',
        'settings',
      ]);
    });

    test('keeps the actions that match, best first', () {
      expect(actionsMatching(actions, 'set').first.id, 'settings');
      expect(actionsMatching(actions, 'sy').map((a) => a.id), ['sync']);
      expect(actionsMatching(actions, 'zzz'), isEmpty);
    });
  });

  group('PaletteShortcut', () {
    const sync = PaletteShortcut(LogicalKeyboardKey.keyS, shift: true);
    const settings = PaletteShortcut(LogicalKeyboardKey.comma);

    test('is written with symbols on macOS and with names elsewhere', () {
      expect(sync.display(isMac: true), '⌘⇧S');
      expect(sync.display(isMac: false), 'Ctrl+Shift+S');
      expect(settings.display(isMac: true), '⌘,');
      expect(settings.display(isMac: false), 'Ctrl+,');
    });

    test('uses Cmd on macOS and Ctrl elsewhere as the activator', () {
      final mac = sync.activator(isMac: true);
      expect(mac.meta, isTrue);
      expect(mac.control, isFalse);
      expect(mac.shift, isTrue);
      final other = sync.activator(isMac: false);
      expect(other.control, isTrue);
      expect(other.meta, isFalse);
    });
  });
}
