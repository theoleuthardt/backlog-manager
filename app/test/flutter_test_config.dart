import 'dart:async';

import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/features/updates/whats_new_sheet.dart';
import 'package:backlog_manager/shell/search_hint.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// Runs before every test file: the sky of the window stays still, so tests
/// settle and goldens do not depend on the time, and the first-run hint of the
/// search and the changes of a new version stay away unless a test asks for
/// them. After every test the preferences are
/// back to what a fresh process has (not available): a test file that sets mock
/// values must not leave them to the next file when several run in one process
/// (tool/test/bundles.dart).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  atmosphereMotion = false;
  coverImageDelay = Duration.zero;
  searchHintEnabled = false;
  whatsNewEnabled = false;
  final preferences = SharedPreferencesStorePlatform.instance;
  tearDown(() {
    SharedPreferencesStorePlatform.instance = preferences;
    SharedPreferences.resetStatic();
  });
  await testMain();
}
