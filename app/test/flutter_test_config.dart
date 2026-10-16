import 'dart:async';

import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/shell/search_hint.dart';

/// Runs before every test file: the sky of the window stays still, so tests
/// settle and goldens do not depend on the time, and the first-run hint of the
/// search stays away unless a test asks for it.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  atmosphereMotion = false;
  coverImageDelay = Duration.zero;
  searchHintEnabled = false;
  await testMain();
}
