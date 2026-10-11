import 'dart:async';

import 'package:backlog_manager/design/atmosphere.dart';

/// Runs before every test file: the sky of the window stays still, so tests
/// settle and goldens do not depend on the time.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  atmosphereMotion = false;
  await testMain();
}
