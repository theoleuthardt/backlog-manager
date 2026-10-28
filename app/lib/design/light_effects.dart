import 'dart:async';

import 'package:backlog_manager/design/frame_strain.dart';
import 'package:backlog_manager/platform/desktop.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Why the effects of the window are lightened on a phone or handheld.
enum LightEffectsReason { powerSave, frameStrain }

const _powerChannel = EventChannel('dev.theocloud.blm/power');

/// Whether the system saves power (battery saver on Android, Low Power Mode
/// on iOS): the current value when listened to, then every change.
final powerSaveEventsProvider = Provider<Stream<bool>>(
  (ref) => _powerChannel.receiveBroadcastStream().map((on) => on == true),
);

/// Whether a phone or handheld saves power right now; always false on the
/// desktop, which has no such channel, and a stream that fails leaves it off.
class PowerSaveNotifier extends Notifier<bool> {
  @override
  bool build() {
    if (ref.watch(isDesktopProvider)) return false;
    final subscription = ref
        .watch(powerSaveEventsProvider)
        .listen((on) => state = on, onError: (Object _) {});
    ref.onDispose(subscription.cancel);
    return false;
  }
}

final powerSaveProvider = NotifierProvider<PowerSaveNotifier, bool>(
  PowerSaveNotifier.new,
);

/// Whether the phone or handheld cannot keep up with the full effects
/// ([FrameStrain] over the frame times of the app); always false on the
/// desktop, where the settings switch the effects off by hand.
class FrameStrainNotifier extends Notifier<bool> {
  final _strain = FrameStrain();

  @override
  bool build() {
    if (ref.watch(isDesktopProvider)) return false;
    void onTimings(List<FrameTiming> timings) {
      for (final timing in timings) {
        final build = timing.buildDuration;
        final raster = timing.rasterDuration;
        record(build > raster ? build : raster);
      }
    }

    SchedulerBinding.instance.addTimingsCallback(onTimings);
    ref.onDispose(
      () => SchedulerBinding.instance.removeTimingsCallback(onTimings),
    );
    return false;
  }

  void record(Duration frame) {
    if (state || ref.read(isDesktopProvider)) return;
    if (_strain.add(frame)) state = true;
  }
}

final frameStrainProvider = NotifierProvider<FrameStrainNotifier, bool>(
  FrameStrainNotifier.new,
);

/// Why the moving sky, the drifting glow, the orbs of the Freaky theme and the
/// blur of the glass are off on a phone or handheld, or null while they show
/// as the settings say: the system saves power, or frames kept dropping with
/// them. Everything else of the window stays as it is.
final lightEffectsProvider = Provider<LightEffectsReason?>((ref) {
  if (ref.watch(powerSaveProvider)) return LightEffectsReason.powerSave;
  if (ref.watch(frameStrainProvider)) return LightEffectsReason.frameStrain;
  return null;
});
