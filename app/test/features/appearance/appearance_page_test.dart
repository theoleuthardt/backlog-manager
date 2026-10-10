import 'package:backlog_manager/data/theme_store.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/features/appearance/theme_actions.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/palette_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../settings/settings_page_test.dart'
    show Settings, SignedInAs, openSettings, theo;

class MemoryThemeStore implements ThemeStore {
  MemoryThemeStore([this.stored]);

  ThemeSelection? stored;
  final writes = <String>[];

  @override
  Future<ThemeSelection?> read() async => stored;

  @override
  Future<void> write(String id, List<CustomTheme> customThemes) async {
    writes.add(id);
    stored = ThemeSelection(id: id, customThemes: customThemes);
  }
}

const neon = CustomTheme(
  id: 'custom-neon',
  name: 'Neon',
  colors: ThemeColors(
    background: '#0a0014',
    surface: '#1a0033',
    foreground: '#f5e9ff',
    accent: '#ff2bd6',
    border: '#5b2a86',
    glow: '#00e5ff',
  ),
);

SessionUser user({
  String theme = 'shelfOled',
  List<CustomTheme> custom = const [],
}) => SessionUser(
  name: theo.name,
  email: theo.email,
  setupCompleted: true,
  theme: theme,
  customThemes: custom,
);

class Opened {
  Opened(this.settings, this.store);

  final Settings settings;
  final MemoryThemeStore store;

  ProviderContainer get container => settings.container;

  String get activeId => container.read(themeIdProvider);

  List<CustomTheme> get custom => container.read(customThemesProvider);

  List<Map<String, Object?>> get updates => [
    for (final update in settings.users.updates) update.toJson(),
  ];
}

Future<Opened> open(
  WidgetTester tester, {
  SessionUser? account,
  String location = AppRoutes.appearance,
  MemoryThemeStore? store,
  Future<void> Function(Object update)? onUpdate,
}) async {
  final themeStore = store ?? MemoryThemeStore();
  final settings = await openSettings(
    tester,
    user: account ?? user(),
    location: location,
    overrides: [themeStoreProvider.overrideWithValue(themeStore)],
    onUpdate: onUpdate == null ? null : (update) => onUpdate(update),
  );
  return Opened(settings, themeStore);
}

Future<void> dismissToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 6));

Future<void> typeHex(WidgetTester tester, String field, String text) async {
  await tester.enterText(find.byKey(Key('theme-hex-$field')), text);
  await tester.pump();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('theme-save')));
  await tester.pumpAndSettle();
}

Future<void> saveNeon(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('theme-name')), 'Neon');
  await typeHex(tester, 'accent', '#ff2bd6');
  await save(tester);
}

bool saveEnabled(WidgetTester tester) =>
    tester.widget<ShelfButton>(find.byKey(const Key('theme-save'))).onPressed !=
    null;

void main() {
  group('the themes', () {
    testWidgets('lists the built-in themes with Classic dark last', (
      tester,
    ) async {
      await open(tester);

      expect(find.byKey(const Key('page-appearance')), findsOneWidget);
      expect(find.text('Shelf OLED'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Colorful'), findsOneWidget);
      expect(find.text('Freaky'), findsOneWidget);
      expect(find.text('Classic dark'), findsOneWidget);
      expect(find.text('No custom themes yet.'), findsOneWidget);
    });

    testWidgets('marks the active theme', (tester) async {
      await open(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('theme-item-shelfOled')),
          matching: find.text('active'),
        ),
        findsOneWidget,
      );
      expect(find.text('active'), findsOneWidget);
    });

    testWidgets('lists the custom themes of the account', (tester) async {
      await open(tester, account: user(custom: [neon]));

      expect(find.text('Neon'), findsOneWidget);
      expect(find.text('No custom themes yet.'), findsNothing);
    });

    testWidgets('picking a theme switches to it and saves the id only', (
      tester,
    ) async {
      final opened = await open(tester);

      await tester.tap(find.byKey(const Key('theme-item-light')));
      await tester.pumpAndSettle();

      expect(opened.activeId, 'light');
      expect(opened.updates, [
        {'theme': 'light'},
      ]);
      expect(opened.store.stored?.id, 'light');
    });

    testWidgets('a failed save puts the previous theme back', (tester) async {
      final opened = await open(
        tester,
        onUpdate: (_) async => throw Exception('offline'),
      );

      await tester.tap(find.byKey(const Key('theme-item-light')));
      await tester.pumpAndSettle();

      expect(opened.activeId, 'shelfOled');
      expect(find.text('Failed to save theme'), findsOneWidget);
      expect(opened.store.stored?.id, 'shelfOled');
      await dismissToast(tester);
    });
  });

  group('creating a theme', () {
    testWidgets('needs a name and valid colours', (tester) async {
      await open(tester);

      expect(saveEnabled(tester), isFalse);
      await tester.enterText(find.byKey(const Key('theme-name')), 'Neon');
      await tester.pump();
      expect(saveEnabled(tester), isTrue);

      await typeHex(tester, 'accent', '#12');
      expect(saveEnabled(tester), isFalse);
      expect(find.text('Use a colour like #1a2b3c'), findsOneWidget);
    });

    testWidgets('saves the theme, switches to it and says so', (tester) async {
      final opened = await open(tester);

      await saveNeon(tester);

      expect(opened.custom, hasLength(1));
      expect(opened.custom.single.name, 'Neon');
      expect(opened.custom.single.colors.accent, '#ff2bd6');
      expect(opened.activeId, opened.custom.single.id);
      expect(opened.activeId, startsWith('custom-'));
      final update = opened.updates.single;
      expect(update['theme'], opened.activeId);
      expect((update['custom_themes']! as List<Object?>).single, {
        'id': opened.activeId,
        'name': 'Neon',
        'background': '#000000',
        'surface': '#0b0b0e',
        'foreground': '#f2f2f3',
        'accent': '#ff2bd6',
        'border': '#353a4c',
        'glow': '#3b82f6',
      });
      expect(find.text('Theme "Neon" saved'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('Start from takes the colours of a built-in theme', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.byKey(const Key('theme-start-from')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light').last);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('theme-hex-background')))
            .controller!
            .text,
        '#f5f4ef',
      );
    });

    testWidgets('previews live and drops the preview when leaving', (
      tester,
    ) async {
      final opened = await open(tester);

      await typeHex(tester, 'background', '#102030');
      expect(
        opened.container.read(themePreviewProvider)?.background,
        '#102030',
      );

      await typeHex(tester, 'background', '#10');
      expect(opened.container.read(themePreviewProvider), isNull);

      await typeHex(tester, 'background', '#203040');
      opened.container.read(routerProvider).go(AppRoutes.library);
      await tester.pumpAndSettle();
      expect(opened.container.read(themePreviewProvider), isNull);
    });

    testWidgets('Reset returns to the colours it started with', (tester) async {
      final opened = await open(tester);
      await typeHex(tester, 'accent', '#123456');

      await tester.tap(find.byKey(const Key('theme-reset')));
      await tester.pump();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('theme-hex-accent')))
            .controller!
            .text,
        '#f5a524',
      );
      expect(opened.container.read(themePreviewProvider)?.accent, '#f5a524');
    });

    testWidgets('shows the limit and refuses an eleventh theme', (
      tester,
    ) async {
      final many = [
        for (var i = 0; i < maxCustomThemes; i++)
          CustomTheme(id: 'custom-$i', name: 'Theme $i', colors: neon.colors),
      ];
      await open(tester, account: user(custom: many));

      await tester.enterText(find.byKey(const Key('theme-name')), 'One more');
      await tester.pump();

      expect(find.text(themeLimitMessage), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });
  });

  group('editing and deleting', () {
    testWidgets('editing loads the theme and saves it in place', (
      tester,
    ) async {
      final opened = await open(tester, account: user(custom: [neon]));

      await tester.tap(find.byKey(const Key('theme-edit-Neon')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('theme-name')))
            .controller!
            .text,
        'Neon',
      );
      await typeHex(tester, 'glow', '#00ff00');
      await save(tester);

      expect(opened.custom, hasLength(1));
      expect(opened.custom.single.id, 'custom-neon');
      expect(opened.custom.single.colors.glow, '#00ff00');
      await dismissToast(tester);
    });

    testWidgets('New theme leaves the edit', (tester) async {
      await open(tester, account: user(custom: [neon]));
      await tester.tap(find.byKey(const Key('theme-edit-Neon')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('theme-new')));
      await tester.pump();

      expect(find.text('Save theme'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('theme-name')))
            .controller!
            .text,
        '',
      );
    });

    testWidgets('deleting removes the theme and says so', (tester) async {
      final opened = await open(tester, account: user(custom: [neon]));

      await tester.tap(find.byKey(const Key('theme-delete-Neon')));
      await tester.pumpAndSettle();

      expect(opened.custom, isEmpty);
      expect(find.text('Theme "Neon" deleted'), findsOneWidget);
      expect(opened.updates.single['custom_themes'], isEmpty);
      await dismissToast(tester);
    });

    testWidgets('deleting the active theme falls back to the default', (
      tester,
    ) async {
      final opened = await open(
        tester,
        account: user(theme: 'custom-neon', custom: [neon]),
      );
      expect(opened.activeId, 'custom-neon');

      await tester.tap(find.byKey(const Key('theme-delete-Neon')));
      await tester.pumpAndSettle();

      expect(opened.activeId, defaultThemeId);
      expect(opened.updates.single['theme'], defaultThemeId);
      await dismissToast(tester);
    });
  });

  group('the account and the device', () {
    testWidgets('the theme of the account applies', (tester) async {
      final opened = await open(
        tester,
        account: user(theme: 'custom-neon', custom: [neon]),
      );

      expect(opened.activeId, 'custom-neon');
      expect(opened.custom.single.name, 'Neon');
      expect(opened.store.stored?.id, 'custom-neon');
    });

    test('the theme on the device applies while nobody is signed in', () async {
      final container = ProviderContainer(
        overrides: [
          themeStoreProvider.overrideWithValue(
            MemoryThemeStore(
              const ThemeSelection(id: 'custom-neon', customThemes: [neon]),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(themeSyncProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(themeIdProvider), 'custom-neon');
      expect(container.read(customThemesProvider).single.name, 'Neon');
    });

    test(
      'a stored theme does not replace the one of a signed-in account',
      () async {
        final container = ProviderContainer(
          overrides: [
            themeStoreProvider.overrideWithValue(
              MemoryThemeStore(
                const ThemeSelection(id: 'colorful', customThemes: []),
              ),
            ),
            sessionProvider.overrideWith(
              () => SignedInAs(user(theme: 'light')),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(themeSyncProvider);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(themeIdProvider), 'light');
      },
    );
  });

  group('the switcher', () {
    testWidgets('the account row lists the themes and the creator', (
      tester,
    ) async {
      await open(
        tester,
        account: user(custom: [neon]),
        location: AppRoutes.library,
      );

      await tester.tap(find.byKey(const Key('account-row')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account-theme-shelfOled')), findsOneWidget);
      expect(find.byKey(const Key('account-theme-dark')), findsOneWidget);
      expect(
        find.byKey(const Key('account-theme-custom-neon')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('account-theme-creator')), findsOneWidget);
    });

    testWidgets('picking a theme there switches and saves it', (tester) async {
      final opened = await open(
        tester,
        account: user(custom: [neon]),
        location: AppRoutes.library,
      );

      await tester.tap(find.byKey(const Key('account-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-theme-custom-neon')));
      await tester.pumpAndSettle();

      expect(opened.activeId, 'custom-neon');
      expect(opened.updates, [
        {'theme': 'custom-neon'},
      ]);
    });

    testWidgets('Theme creator opens the appearance screen', (tester) async {
      await open(tester, location: AppRoutes.library);

      await tester.tap(find.byKey(const Key('account-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-theme-creator')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('page-appearance')), findsOneWidget);
    });

    testWidgets('the palette switches to every theme, also custom ones', (
      tester,
    ) async {
      final opened = await open(
        tester,
        account: user(custom: [neon]),
        location: AppRoutes.library,
      );
      await tester.pump();

      final actions = {
        for (final action in opened.container.read(paletteRegistryProvider))
          action.id: action,
      };
      expect(actions.keys, containsAll(['theme-light', 'theme-custom-neon']));
      expect(actions['theme-custom-neon']!.label, 'Switch theme to Neon');

      actions['theme-light']!.run();
      await tester.pumpAndSettle();
      expect(opened.activeId, 'light');
    });

    testWidgets('the palette forgets a deleted custom theme', (tester) async {
      final opened = await open(
        tester,
        account: user(custom: [neon]),
        location: AppRoutes.library,
      );
      await tester.pump();

      opened.container.read(customThemesProvider.notifier).set(const []);
      await tester.pump();

      expect(
        opened.container
            .read(paletteRegistryProvider)
            .map((action) => action.id),
        isNot(contains('theme-custom-neon')),
      );
    });
  });

  for (final themeId in ['shelfOled', 'light']) {
    testWidgets('golden: the appearance screen in $themeId', tags: 'golden', (
      tester,
    ) async {
      final opened = await open(
        tester,
        account: user(theme: themeId, custom: [neon]),
      );
      await tester.tap(find.byKey(const Key('theme-edit-Neon')));
      await tester.pump();
      await typeHex(tester, 'accent', '#33cc99');
      await tester.pumpAndSettle();
      expect(opened.activeId, themeId);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/appearance_$themeId.png'),
      );
    });
  }
}
