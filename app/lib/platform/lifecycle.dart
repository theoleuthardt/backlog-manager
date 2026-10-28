import 'package:backlog_manager/platform/desktop.dart';
import 'package:flutter/widgets.dart';

/// How often the app has gone to the background on a phone or tablet (Android
/// and iOS suspend it there, which cuts its open connections). A running
/// stream compares it with the value at its start to tell such a cut from an
/// error of the network or the server. The desktop keeps running when it is
/// hidden and never counts.
final backgroundEntries = ValueNotifier<int>(0);

AppLifecycleListener? _listener;

/// Starts counting [backgroundEntries]; called once by `main`.
void watchBackground() {
  if (_listener != null || isDesktopPlatform()) return;
  _listener = AppLifecycleListener(onHide: () => backgroundEntries.value++);
}
