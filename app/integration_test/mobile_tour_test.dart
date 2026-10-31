import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/auth/token_store.dart';
import 'package:backlog_manager/data/release_source.dart';
import 'package:backlog_manager/data/selection_providers.dart';
import 'package:backlog_manager/data/whats_new.dart';
import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/design/focus_glide.dart';
import 'package:backlog_manager/design/light_effects.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/platform/csv_file_picker.dart';
import 'package:backlog_manager/platform/desktop.dart';
import 'package:backlog_manager/platform/file_saver.dart';
import 'package:backlog_manager/platform/image_file_picker.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/auth/fakes.dart' show MemoryTokenStore;

/// The device the tour runs on: `phone` (portrait, touch) or `handheld`
/// (landscape, driven with gamepad buttons).
const _device = String.fromEnvironment('TOUR_DEVICE', defaultValue: 'phone');
const _server = String.fromEnvironment(
  'TOUR_SERVER',
  defaultValue: 'http://localhost:8000',
);
const _email = String.fromEnvironment(
  'TOUR_EMAIL',
  defaultValue: 'theo@example.com',
);
const _password = String.fromEnvironment('TOUR_PASSWORD');

/// A run on the desktop of a developer instead of an emulator: the app is
/// told it runs on a touch screen of the size of the device.
const _local = bool.fromEnvironment('TOUR_LOCAL');

/// The mobile tour (#576): the real app against a real, seeded backend
/// (`backend/scripts/seed_mobile_tour.py`) on an Android emulator, walking
/// through every page and sheet and keeping a screenshot of each step. It
/// does not fail on what it finds: every error of the app (layout overflows
/// included) is recorded with its step, and a step that throws is recorded
/// and skipped, so one run shows everything. The screenshots and the report
/// go to the driver (`test_driver/tour_driver.dart`) as report data. On the
/// emulator the app runs with the lighter effects (no sky, glow, orbs or
/// blur), because its software GPU took seconds per frame with them until
/// the emulator hung and died (#588).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  atmosphereMotion = false;

  testWidgets('mobile tour on a $_device', (tester) async {
    final shots = <String, String>{};
    final steps = <Map<String, Object?>>[];
    var step = 'start';
    var number = 0;

    final reportError = FlutterError.onError;
    FlutterError.onError = (details) {
      steps.add({
        'step': step,
        'error': details.exceptionAsString().split('\n').take(6).join('\n'),
      });
    };
    addTearDown(() => FlutterError.onError = reportError);

    if (_local) {
      tester.view.physicalSize = _device == 'phone'
          ? const Size(402, 874)
          : const Size(853, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        serverUrlProvider.overrideWith((ref) async => _server),
        csvFilePickerProvider.overrideWithValue(const _TourCsvPicker()),
        imageFilePickerProvider.overrideWithValue(const _TourImagePicker()),
        fileSaverProvider.overrideWithValue(const _TourFileSaver()),
        installedVersionProvider.overrideWith((ref) async => '0.9.17'),
        whatsNewStoreProvider.overrideWithValue(_TourWhatsNewStore()),
        if (!_local)
          lightEffectsProvider.overrideWithValue(LightEffectsReason.powerSave),
        if (_local) ...[
          isDesktopProvider.overrideWithValue(false),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        ],
      ],
    );
    addTearDown(container.dispose);
    await container.read(tokenStoreProvider).clear();

    Future<void> settle([int frames = 12]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> shot(String name, {bool settled = true}) async {
      if (settled) await settle();
      final view = tester.binding.renderViews.first;
      final layer = view.debugLayer! as OffsetLayer;
      final image = await layer.toImage(Offset.zero & view.size);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      number++;
      final key = '${number.toString().padLeft(3, '0')}_$name';
      shots[key] = base64Encode(bytes!.buffer.asUint8List());
      steps.add({'step': step, 'shot': key});
    }

    Future<void> run(String name, Future<void> Function() body) async {
      step = name;
      debugPrint('tour step: $name');
      try {
        await body();
      } on Object catch (error, stack) {
        steps.add({
          'step': name,
          'failed': '$error',
          'stack': stack.toString().split('\n').take(8).join('\n'),
        });
      }
    }

    Future<void> closeLayers() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape, platform: 'android');
      await settle(2);
      final navigator = container
          .read(routerProvider)
          .routerDelegate
          .navigatorKey
          .currentState;
      navigator?.popUntil((route) => route is! PopupRoute);
      container.read(paletteOpenProvider.notifier).close();
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(4);
    }

    Future<void> tapIfThere(Finder finder) async {
      if (finder.evaluate().isEmpty) {
        steps.add({
          'step': step,
          'missing': finder.describeMatch(Plurality.zero),
        });
        return;
      }
      await tester.ensureVisible(finder.first);
      await settle(3);
      if (finder.evaluate().isEmpty) {
        steps.add({
          'step': step,
          'missing': '${finder.describeMatch(Plurality.zero)} after scrolling',
        });
        return;
      }
      await tester.tap(finder.first, warnIfMissed: false);
      await settle(4);
    }

    Future<void> scrollToTop() async {
      for (final state in tester.stateList<ScrollableState>(
        find.byType(Scrollable),
      )) {
        if (state.position.axis == Axis.vertical &&
            state.position.pixels != 0) {
          state.position.jumpTo(0);
        }
      }
      await settle(3);
    }

    Future<void> scrollDown() async {
      final scrollables = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .where((state) => state.position.axis == Axis.vertical)
          .toList();
      if (scrollables.isEmpty) return;
      final main = scrollables.reduce(
        (a, b) => a.position.viewportDimension >= b.position.viewportDimension
            ? a
            : b,
      );
      main.position.jumpTo(
        (main.position.pixels + main.position.viewportDimension * 0.8).clamp(
          0,
          main.position.maxScrollExtent,
        ),
      );
      await settle(4);
    }

    Future<void> open(String location) async {
      container.read(routerProvider).go(location);
      await settle(15);
      await scrollToTop();
    }

    Future<void> press(LogicalKeyboardKey key, {int times = 1}) async {
      for (var i = 0; i < times; i++) {
        await tester.sendKeyEvent(key, platform: 'android');
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    Future<void> tour() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BacklogManagerApp(),
        ),
      );
      await container.read(authControllerProvider.notifier).restore();
      await settle(30);

      await run('sign in', () async {
        await shot('sign_in');
        await tester.enterText(
          find.widgetWithText(ShelfField, 'Email'),
          _email,
        );
        await tester.enterText(
          find.widgetWithText(ShelfField, 'Password'),
          _password,
        );
        await shot('sign_in_filled');
        await tapIfThere(find.byKey(const Key('sign-in-submit')));
        await settle(40);
        if (find.byKey(const Key('page-home')).evaluate().isEmpty) {
          throw StateError('the sign-in did not reach the home page');
        }
        await shot('home');
      });

      await run('whats new', () async {
        await settle(20);
        await shot('whats_new');
        await tapIfThere(find.byKey(const Key('whats-new-done')));
        await settle(4);
      });

      await run('home', () async {
        await open(AppRoutes.home);
        await shot('home');
        await scrollDown();
        await shot('home_scrolled');
      });

      await run('library', () async {
        await open(AppRoutes.library);
        await shot('library_grid');
        await scrollDown();
        await shot('library_grid_scrolled');
      });

      await run('library menus', () async {
        await open(AppRoutes.library);
        await tapIfThere(find.byKey(const Key('library-actions')));
        await shot('library_actions_menu');
        await closeLayers();
        await tapIfThere(find.text('+ Add filter'));
        await shot('library_add_filter');
        await closeLayers();
        await tapIfThere(find.byKey(const Key('library-view-menu')));
        await shot('library_view_menu');
        await tapIfThere(find.text('List'));
        await shot('library_list');
        await tapIfThere(find.byKey(const Key('library-view-menu')));
        await tapIfThere(find.text('Grid'));
        await closeLayers();
        await tapIfThere(find.byKey(const Key('owned-only')));
        await shot('library_owned_only');
        await tapIfThere(find.byKey(const Key('owned-only')));
      });

      await run('selection', () async {
        await open(AppRoutes.library);
        await tapIfThere(find.byKey(const Key('select-toggle')));
        final tiles = find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'library-tile-',
              ),
        );
        await tapIfThere(tiles);
        await shot('library_selection');
        await closeLayers();
        container.read(selectionProvider.notifier).end();
        await settle(4);
      });

      int? firstEntryId() {
        for (final element
            in find
                .byWidgetPredicate(
                  (widget) =>
                      widget.key is ValueKey<String> &&
                      (widget.key! as ValueKey<String>).value.startsWith(
                        'library-tile-',
                      ),
                )
                .evaluate()) {
          final key = element.widget.key! as ValueKey<String>;
          return int.tryParse(key.value.substring('library-tile-'.length));
        }
        return null;
      }

      await run('inspector', () async {
        await open(AppRoutes.library);
        final id = firstEntryId();
        if (id == null) throw StateError('no entries to inspect');
        await open('${AppRoutes.library}?entry=$id');
        await shot('inspector_overview');
        for (final tab in ['Progress', 'Notes', 'Review', 'Mods', 'Trailer']) {
          await tapIfThere(find.text(tab));
          await shot('inspector_${tab.toLowerCase()}');
        }
        await open(AppRoutes.library);
      });

      await run('add game', () async {
        await open(AppRoutes.library);
        container.read(addGameRequestProvider.notifier).request();
        await settle(10);
        await shot('add_game');
        final field = find.byType(TextField);
        if (field.evaluate().isNotEmpty) {
          await tester.tap(field.last);
          await tester.enterText(field.last, 'Hades');
          await settle(30);
          await shot('add_game_search');
        }
        await closeLayers();
      });

      await run('random pull', () async {
        await open(AppRoutes.home);
        container.read(randomPullRequestProvider.notifier).request();
        await settle(10);
        await shot('random_pull');
        await tapIfThere(find.text('Pull'));
        await settle(40);
        await shot('random_pull_result');
        await closeLayers();
      });

      await run('sheets', () async {
        await open(AppRoutes.library);
        container.read(igdbSyncRequestProvider.notifier).request();
        await settle(10);
        await shot('igdb_sync');
        await closeLayers();
        await tapIfThere(find.byKey(const Key('library-actions')));
        await tapIfThere(find.text('Find duplicate games'));
        await settle(10);
        await shot('duplicates');
        await closeLayers();
        container.read(paletteOpenProvider.notifier).open();
        await settle(6);
        await shot('command_palette');
        await closeLayers();
        await tapIfThere(find.byKey(const Key('nav-more')));
        await shot('more_sheet');
        await closeLayers();
      });

      for (final (name, route) in [
        ('creation_tool', AppRoutes.creationTool),
        ('steam', AppRoutes.steam),
        ('import_csv', AppRoutes.import),
        ('export', AppRoutes.export),
        ('appearance', AppRoutes.appearance),
      ]) {
        await run(name, () async {
          await open(route);
          await shot(name);
        });
      }

      await run('space', () async {
        await open(AppRoutes.space);
        await shot('space');
        await scrollDown();
        await shot('space_scrolled');
        await tapIfThere(find.byKey(const Key('library-actions')));
        await tapIfThere(find.textContaining('Space backups'));
        await settle(10);
        await shot('space_backups');
        await closeLayers();
      });

      for (final tab in [
        'general',
        'security',
        'integrations',
        'backups',
        'updates',
        'about',
      ]) {
        await run('settings $tab', () async {
          await open('${AppRoutes.settings}?tab=$tab');
          await shot('settings_$tab');
        });
      }

      Future<void> typeInto(Finder finder, String text) async {
        if (finder.evaluate().isEmpty) {
          steps.add({
            'step': step,
            'missing': finder.describeMatch(Plurality.zero),
          });
          return;
        }
        final field = find.descendant(
          of: finder.first,
          matching: find.byType(EditableText),
          matchRoot: true,
        );
        if (field.evaluate().isEmpty) {
          steps.add({
            'step': step,
            'missing': 'a text field in ${finder.describeMatch(Plurality.one)}',
          });
          return;
        }
        await tester.ensureVisible(field.first);
        await tester.tap(field.first, warnIfMissed: false);
        await tester.enterText(field.first, text);
        await settle(6);
      }

      Future<void> openFirstEntry() async {
        await open(AppRoutes.library);
        final id = firstEntryId();
        if (id == null) throw StateError('no entries to inspect');
        await open('${AppRoutes.library}?entry=$id');
      }

      await run('edit a game', () async {
        await openFirstEntry();
        await tapIfThere(find.byKey(const Key('status-select')));
        await shot('edit_status_menu');
        await tapIfThere(find.byKey(const Key('status-option-In Progress')));
        await shot('edit_status_changed');
        await typeInto(find.byKey(const Key('inspector-playtime')), '12.5');
        await tapIfThere(find.text('7'));
        await shot('edit_playtime_interest');
        await tapIfThere(find.text('Notes'));
        await typeInto(
          find.byKey(const Key('inspector-note')),
          'Finish the main story first.',
        );
        await shot('edit_note');
        await tapIfThere(find.text('Mods'));
        await tapIfThere(find.byKey(const Key('mod-add')));
        await typeInto(find.byKey(const Key('mod-name')), 'Tour mod');
        await typeInto(
          find.byKey(const Key('mod-url')),
          'https://www.nexusmods.com/',
        );
        await shot('edit_mod_sheet');
        await tapIfThere(find.byKey(const Key('mod-save')));
        await shot('edit_mod_saved');
        await tapIfThere(find.text('Category'));
        await shot('edit_category_menu');
        await tapIfThere(find.text('Short games'));
        await shot('edit_category_added');
        await closeLayers();
      });

      await run('game sheets', () async {
        for (final (key, name) in [
          ('inspector-wrong-game', 'wrong_game'),
          ('inspector-change-cover', 'change_cover'),
          ('inspector-update-image', 'image_link'),
          ('inspector-prices', 'prices'),
          ('inspector-platform-manage', 'manage_platforms'),
        ]) {
          await openFirstEntry();
          await tapIfThere(find.byKey(Key(key)));
          await settle(10);
          await shot('sheet_$name');
          await closeLayers();
        }
        await openFirstEntry();
        await tapIfThere(find.text('Add to Shared Space'));
        await settle(10);
        await shot('sheet_add_to_space');
        await closeLayers();
        await openFirstEntry();
        await tapIfThere(find.byKey(const Key('inspector-delete')));
        await shot('sheet_delete_confirm');
        await closeLayers();
      });

      await run('complete and review', () async {
        await openFirstEntry();
        await tapIfThere(find.byKey(const Key('status-select')));
        await tapIfThere(find.byKey(const Key('status-option-Completed')));
        await settle(6);
        await shot('complete_dialog');
        await closeLayers();
        await tapIfThere(find.text('Review'));
        await tapIfThere(find.byKey(const Key('star-4')));
        await typeInto(
          find.byKey(const Key('inspector-review')),
          'A great game for the handheld.',
        );
        await shot('review_written');
        await closeLayers();
      });

      await run('filter and sort', () async {
        await open(AppRoutes.library);
        await typeInto(find.byKey(const Key('search-field')), 'Portal');
        await shot('library_search');
        await typeInto(find.byKey(const Key('search-field')), '');
        await tapIfThere(find.text('+ Add filter'));
        await tapIfThere(find.text('Platform'));
        await shot('filter_platform_picker');
        await tapIfThere(find.text('Steam Deck'));
        await closeLayers();
        await shot('filter_platform_active');
        await tapIfThere(find.byKey(const Key('filter-reset')));
        await tapIfThere(find.byTooltip('Sort: Status'));
        await shot('sort_menu');
        await tapIfThere(find.text('Title'));
        await shot('sorted_by_title');
        await tapIfThere(find.byTooltip('Sort: Title'));
        await tapIfThere(find.text('Status'));
        await closeLayers();
      });

      await run('groups', () async {
        await open(AppRoutes.library);
        final toggle = find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'group-toggle-',
              ),
        );
        await tapIfThere(toggle);
        await shot('group_collapsed');
        await tapIfThere(toggle);
        final order = find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'group-entry-order-',
              ),
        );
        await tapIfThere(order);
        await shot('group_order_menu');
        await closeLayers();
      });

      await run('bulk actions', () async {
        await open(AppRoutes.library);
        await tapIfThere(find.byKey(const Key('select-toggle')));
        final tiles = find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'library-tile-',
              ),
        );
        if (tiles.evaluate().length > 1) {
          await tapIfThere(tiles.at(0));
          await tapIfThere(tiles.at(1));
        }
        await tapIfThere(find.text('Set Status'));
        await shot('bulk_set_status');
        await closeLayers();
        await tapIfThere(find.text('Categories'));
        await shot('bulk_categories');
        await closeLayers();
        container.read(selectionProvider.notifier).end();
        await settle(4);
      });

      await run('create a game', () async {
        await open(AppRoutes.library);
        container.read(addGameRequestProvider.notifier).request();
        await settle(8);
        await tapIfThere(find.text('Create it as a custom game'));
        await settle(10);
        await shot('creation_custom');
        await typeInto(find.byKey(const Key('creation-title')), 'Tour Game');
        await tapIfThere(find.byKey(const Key('creation-platform')));
        await tapIfThere(find.text('PC'));
        await closeLayers();
        await typeInto(find.byKey(const Key('creation-genre')), 'Puzzle');
        await shot('creation_filled');
        await tapIfThere(find.byKey(const Key('creation-submit')));
        await settle(15);
        await shot('creation_submitted');
      });

      await run('csv import', () async {
        await open(AppRoutes.import);
        await tapIfThere(find.byKey(const Key('import-choose')));
        await settle(15);
        await shot('import_mapping');
        await tapIfThere(find.byKey(const Key('import-preview')));
        await settle(60);
        await shot('import_preview');
        await tapIfThere(find.byKey(const Key('import-submit')));
        await settle(40);
        await shot('import_done');
      });

      await run('csv export', () async {
        await open(AppRoutes.export);
        await tapIfThere(find.byKey(const Key('export-save')));
        await settle(20);
        await shot('export_done');
      });

      await run('themes', () async {
        await open(AppRoutes.appearance);
        await tapIfThere(find.byKey(const Key('theme-item-light')));
        await shot('theme_light');
        await open(AppRoutes.library);
        await shot('theme_light_library');
        await open(AppRoutes.appearance);
        await typeInto(find.byKey(const Key('theme-name')), 'Tour Night');
        await tapIfThere(find.byKey(const Key('theme-save')));
        await shot('theme_saved');
        await tapIfThere(find.byKey(const Key('theme-item-shelfOled')));
        await settle(6);
      });

      await run('settings actions', () async {
        await open('${AppRoutes.settings}?tab=general');
        await tapIfThere(find.byKey(const Key('profile-picture-choose')));
        await settle(20);
        await shot('settings_picture');
        await tapIfThere(find.byKey(const Key('settings-default-sort')));
        await shot('settings_sort_menu');
        await closeLayers();
        await open('${AppRoutes.settings}?tab=security');
        await tapIfThere(find.byKey(const Key('two-factor-enable')));
        await settle(20);
        await shot('settings_two_factor');
        await closeLayers();
        await open('${AppRoutes.settings}?tab=backups');
        await tapIfThere(find.byKey(const Key('backup-create')));
        await settle(15);
        await shot('settings_backup_created');
        await tapIfThere(find.text('Rename'));
        await shot('settings_backup_rename');
        await closeLayers();
        await open('${AppRoutes.settings}?tab=updates');
        await tapIfThere(find.text('Preview'));
        await tapIfThere(find.text('Check for updates'));
        await settle(30);
        await shot('settings_updates_checked');
        await tapIfThere(find.text('Stable'));
      });

      await run('space actions', () async {
        await open(AppRoutes.space);
        await tapIfThere(find.text('Space Info'));
        await shot('space_info');
        await closeLayers();
        await open(AppRoutes.space);
        final id = firstEntryId();
        if (id != null) {
          await open('${AppRoutes.space}?entry=$id');
          await shot('space_inspector');
          await tapIfThere(find.text('Progress'));
          await shot('space_inspector_progress');
        }
        await open(AppRoutes.space);
        await tapIfThere(find.byKey(const Key('add-game-button')));
        await shot('space_add_game');
        await closeLayers();
      });

      await run('home actions', () async {
        await open(AppRoutes.home);
        await tapIfThere(find.text('Random Pull'));
        await tapIfThere(find.text('Pull'));
        await settle(40);
        await tapIfThere(find.text('Open Details'));
        await settle(10);
        await shot('home_pull_open_details');
        await open(AppRoutes.home);
        await tapIfThere(find.text('See All'));
        await settle(10);
        await shot('home_see_all');
        await open(AppRoutes.home);
        await tapIfThere(find.text('Mark as completed'));
        await shot('home_mark_completed');
        await closeLayers();
      });

      await run('palette commands', () async {
        await open(AppRoutes.home);
        container.read(paletteOpenProvider.notifier).open();
        await settle(6);
        await typeInto(find.byKey(const Key('palette-input')), 'steam');
        await shot('palette_typed');
        await tester.sendKeyEvent(
          LogicalKeyboardKey.enter,
          platform: 'android',
        );
        await settle(15);
        await shot('palette_ran');
      });

      Future<void> checkRing(String label) async {
        final node = FocusManager.instance.primaryFocus;
        final focused = node?.context;
        if (node == null || focused == null || node is FocusScopeNode) {
          steps.add({'step': step, 'ring': '$label: nothing has the focus'});
          return;
        }
        if (focused.findAncestorWidgetOfExactType<EditableText>() != null ||
            focused.widget is EditableText) {
          steps.add({
            'step': step,
            'error': 'D-pad focused a text field for typing at $label',
          });
        }
        final hosts = tester.stateList<FocusGlideHostState>(
          find.byType(FocusGlideHost),
        );
        if (hosts.isEmpty) {
          steps.add({'step': step, 'error': 'no focus glide host at $label'});
          return;
        }
        final ring = hosts.first.ringRect;
        final target = node.rect;
        if (ring == null) {
          steps.add({
            'step': step,
            'error': 'no focus ring at $label on $target ($node)',
          });
          return;
        }
        final apart = (ring.center - target.center).distance;
        final hit =
            ring.inflate(6).contains(target.center) ||
            target.inflate(6).contains(ring.center);
        if (!hit) {
          steps.add({
            'step': step,
            'error':
                'focus ring off the control at $label: ring $ring, control '
                '$target, ${apart.toStringAsFixed(0)} px apart ($node)',
          });
        }
      }

      Future<void> walk(String page, List<LogicalKeyboardKey> keys) async {
        for (final (index, key) in keys.indexed) {
          await tester.sendKeyEvent(key, platform: 'android');
          await tester.pump(const Duration(milliseconds: 50));
          if (index % 4 == 0) {
            await shot('${page}_move${index}_mid', settled: false);
          }
          await settle(8);
          await checkRing('$page move $index (${key.debugName})');
          if (index % 4 == 0) await shot('${page}_move${index}_settled');
        }
      }

      const down = LogicalKeyboardKey.arrowDown;
      const up = LogicalKeyboardKey.arrowUp;
      const left = LogicalKeyboardKey.arrowLeft;
      const right = LogicalKeyboardKey.arrowRight;
      final route = [
        down,
        down,
        right,
        right,
        down,
        down,
        left,
        down,
        right,
        right,
        down,
        up,
        up,
        left,
        left,
        down,
      ];

      if (_device == 'handheld') {
        for (final (name, location) in [
          ('home', AppRoutes.home),
          ('library', AppRoutes.library),
          ('space', AppRoutes.space),
          ('steam', AppRoutes.steam),
          ('appearance', AppRoutes.appearance),
          ('settings', '${AppRoutes.settings}?tab=general'),
        ]) {
          await run('pad walk $name', () async {
            await open(location);
            FocusManager.instance.primaryFocus?.unfocus();
            await settle(2);
            await walk(name, route);
          });
        }

        await run('pad walk rail', () async {
          await open(AppRoutes.library);
          FocusManager.instance.primaryFocus?.unfocus();
          await settle(2);
          await walk('rail', [down, left, left, down, down, up, right]);
        });

        await run('pad held', () async {
          await open(AppRoutes.library);
          FocusManager.instance.primaryFocus?.unfocus();
          await settle(2);
          await press(down, times: 2);
          for (var i = 0; i < 8; i++) {
            await tester.sendKeyEvent(down, platform: 'android');
            await tester.pump(const Duration(milliseconds: 70));
          }
          await shot('held_mid', settled: false);
          await settle(10);
          await checkRing('after holding down');
          await shot('held_settled');
          for (var i = 0; i < 8; i++) {
            await tester.sendKeyEvent(up, platform: 'android');
            await tester.pump(const Duration(milliseconds: 70));
          }
          await settle(10);
          await checkRing('after holding up');
          await shot('held_back_up');
        });

        await run('pad inspector', () async {
          await open(AppRoutes.library);
          final id = firstEntryId();
          if (id == null) throw StateError('no entries to inspect');
          await open('${AppRoutes.library}?entry=$id');
          FocusManager.instance.primaryFocus?.unfocus();
          await settle(2);
          await walk('inspector', [
            down,
            down,
            down,
            right,
            right,
            down,
            down,
            down,
            down,
            down,
            down,
            down,
            right,
            down,
            down,
            down,
          ]);
        });

        await run('pad sheets', () async {
          await open(AppRoutes.library);
          container.read(addGameRequestProvider.notifier).request();
          await settle(8);
          await walk('add_game', [down, down, right, down, down, up]);
          await closeLayers();
          container.read(randomPullRequestProvider.notifier).request();
          await settle(8);
          await walk('random_pull', [down, down, down, down, up, right]);
          await closeLayers();
          container.read(paletteOpenProvider.notifier).open();
          await settle(6);
          await walk('palette', [down, down, down, up]);
          await closeLayers();
        });

        await run('pad menus', () async {
          await open(AppRoutes.library);
          FocusManager.instance.primaryFocus?.unfocus();
          await settle(2);
          await press(down, times: 6);
          await press(LogicalKeyboardKey.gameButtonX);
          await settle(6);
          await shot('pad_context_menu');
          await walk('context_menu', [down, down, right, down, left, up]);
          await press(LogicalKeyboardKey.gameButtonB);
          await settle(4);
          await checkRing('after closing the menu with B');
        });
      }

      if (_device == 'handheld') {
        await run('gamepad', () async {
          await open(AppRoutes.library);
          FocusManager.instance.primaryFocus?.unfocus();
          await settle(2);
          await press(LogicalKeyboardKey.arrowDown);
          await shot('pad_first_focus');
          for (var i = 0; i < 4; i++) {
            await press(LogicalKeyboardKey.arrowDown);
            await tester.pump(const Duration(milliseconds: 60));
            await shot('pad_down_$i');
          }
          await press(LogicalKeyboardKey.arrowRight, times: 2);
          await shot('pad_right');
          await press(LogicalKeyboardKey.gameButtonSelect);
          await shot('pad_select_marks');
          await press(LogicalKeyboardKey.gameButtonB);
          await shot('pad_b_ends_selection');
          await press(LogicalKeyboardKey.gameButtonX);
          await shot('pad_x_menu');
          await press(LogicalKeyboardKey.gameButtonB);
          await press(LogicalKeyboardKey.gameButtonA);
          await settle(15);
          await shot('pad_a_opens_game');
          await press(LogicalKeyboardKey.arrowDown, times: 3);
          await shot('pad_inspector_focus');
          await press(LogicalKeyboardKey.gameButtonB);
          await shot('pad_b_closes_inspector');
          await press(LogicalKeyboardKey.gameButtonY);
          await shot('pad_y_palette');
          await press(LogicalKeyboardKey.gameButtonB);
          await press(LogicalKeyboardKey.gameButtonRight1);
          await settle(10);
          await shot('pad_r1');
          await press(LogicalKeyboardKey.gameButtonRight1);
          await settle(10);
          await shot('pad_r1_again');
          await press(LogicalKeyboardKey.gameButtonLeft1, times: 2);
          await press(LogicalKeyboardKey.gameButtonStart);
          await settle(10);
          await shot('pad_start_settings');
          await press(LogicalKeyboardKey.arrowDown, times: 3);
          await shot('pad_settings_focus');
          await press(LogicalKeyboardKey.gameButtonB);
          await settle(10);
          await shot('pad_b_back');
        });
      }
    }

    await runZonedGuarded(tour, (error, stack) {
      steps.add({
        'step': step,
        'uncaught': '$error',
        'stack': stack.toString().split('\n').take(8).join('\n'),
      });
    });
    await container.read(tokenStoreProvider).clear();
    binding.reportData = {
      'device': _device,
      'steps': steps,
      'screenshots': shots,
    };
  }, timeout: const Timeout(Duration(minutes: 60)));
}

const _tourCsv =
    'Title,Platform,Status,Playtime,Genre\n'
    'Celeste,PC,Completed,12,Platformer\n'
    'Fez,PC,Not Started,,Puzzle\n'
    'Into the Breach,Steam Deck,In Progress,4,Strategy\n';

/// The CSV file the import of the tour chooses instead of the open dialog.
class _TourCsvPicker implements CsvFilePicker {
  const _TourCsvPicker();

  @override
  Future<PickedFile?> pick() async => PickedFile(
    name: 'tour.csv',
    readBytes: () async => utf8.encode(_tourCsv),
  );
}

/// The profile picture of the tour: a small orange square made on the spot.
class _TourImagePicker implements ImageFilePicker {
  const _TourImagePicker();

  @override
  Future<PickedFile?> pick() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 64, 64),
      Paint()..color = const Color(0xFFF59E0B),
    );
    final image = await recorder.endRecording().toImage(64, 64);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return PickedFile(
      name: 'avatar.png',
      readBytes: () async => bytes!.buffer.asUint8List(),
    );
  }
}

/// Saves nothing and reports success, so an export does not open the share
/// sheet of the system in the middle of the tour.
class _TourFileSaver implements FileSaver {
  const _TourFileSaver();

  @override
  bool get shares => false;

  @override
  Future<bool> save({
    required String suggestedName,
    required List<int> bytes,
  }) async => true;
}

/// Remembers 0.9.16 as the version shown last, so the tour sees what is new
/// in 0.9.17 (its notes come from GitHub) after the sign-in.
class _TourWhatsNewStore implements WhatsNewStore {
  String? _version = '0.9.16';

  @override
  Future<String?> read() async => _version;

  @override
  Future<void> write(String version) async => _version = version;
}
