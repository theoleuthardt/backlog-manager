import 'dart:async';

import 'package:backlog_manager/design/light_effects.dart';
import 'package:backlog_manager/platform/desktop.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _slow = Duration(milliseconds: 40);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StreamController<bool> powerSave;

  setUp(() => powerSave = StreamController<bool>.broadcast());
  tearDown(() => powerSave.close());

  ProviderContainer containerFor({required bool desktop}) {
    final container = ProviderContainer(
      overrides: [
        isDesktopProvider.overrideWithValue(desktop),
        powerSaveEventsProvider.overrideWithValue(powerSave.stream),
      ],
    );
    addTearDown(container.dispose);
    container.listen(lightEffectsProvider, (_, _) {});
    return container;
  }

  void strain(ProviderContainer container) {
    final notifier = container.read(frameStrainProvider.notifier);
    for (var i = 0; i < 2000; i++) {
      notifier.record(_slow);
    }
  }

  test('a phone starts with the full effects', () {
    final container = containerFor(desktop: false);

    expect(container.read(lightEffectsProvider), isNull);
  });

  test('battery saver lightens the effects while it is on', () async {
    final container = containerFor(desktop: false);

    powerSave.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(lightEffectsProvider), LightEffectsReason.powerSave);

    powerSave.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(lightEffectsProvider), isNull);
  });

  test('frames that keep dropping lighten the effects for the session', () {
    final container = containerFor(desktop: false);

    strain(container);

    expect(
      container.read(lightEffectsProvider),
      LightEffectsReason.frameStrain,
    );
  });

  test('the desktop keeps the full effects', () async {
    final container = containerFor(desktop: true);

    powerSave.add(true);
    await Future<void>.delayed(Duration.zero);
    strain(container);

    expect(container.read(lightEffectsProvider), isNull);
  });
}
