import 'package:backlog_manager/platform/desktop.dart';
import 'package:backlog_manager/shell/window_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

WindowControls controlsOn({required bool desktop}) {
  final container = ProviderContainer(
    overrides: [isDesktopProvider.overrideWithValue(desktop)],
  );
  addTearDown(container.dispose);
  return container.read(windowControlsProvider);
}

void main() {
  test('the desktop controls its own window', () {
    expect(controlsOn(desktop: true), isA<PluginWindowControls>());
  });

  test('a phone or tablet has no window to control', () async {
    final controls = controlsOn(desktop: false);
    expect(controls, isA<NoWindowControls>());
    await controls.minimize();
    await controls.toggleMaximize();
    await controls.startDragging();
    await controls.close();
  });
}
