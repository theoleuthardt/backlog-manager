import 'package:backlog_manager/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1440, 900),
      minimumSize: Size(1000, 640),
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Backlog Manager',
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  runApp(const ProviderScope(child: BacklogManagerApp()));
}
