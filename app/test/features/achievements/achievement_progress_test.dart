import 'dart:async';

import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/features/achievements/achievement_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';

const achievements = [
  wire.AchievementInfo(
    apiname: 'ACH_1',
    displayName: 'First blood',
    description: 'Win a fight',
    icon: null,
    achieved: true,
    unlockTime: 1,
    hidden: false,
  ),
  wire.AchievementInfo(
    apiname: 'ACH_2',
    displayName: 'Secret',
    description: null,
    icon: null,
    achieved: false,
    unlockTime: 0,
    hidden: true,
  ),
];

Future<void> pumpSection(
  WidgetTester tester,
  FakeBacklogApi api, {
  int? steamAppId = 620,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(600, 560);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [backlogApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildShelfTheme(
          ShelfTokens.forTheme(resolveTheme('shelfOled', [])),
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: AchievementProgressSection(steamAppId: steamAppId),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('shows the progress as count and percent', (tester) async {
    final api = FakeBacklogApi()
      ..onAchievements = (_) async => const wire.AchievementProgress(
        unlocked: 1,
        total: 2,
        achievements: achievements,
      );

    await pumpSection(tester, api);

    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('1/2 (50%)'), findsOneWidget);
    expect(find.byKey(const Key('progress-fill')), findsOneWidget);
  });

  testWidgets('shows "Loading achievements..." while it loads', (tester) async {
    final pending = Completer<wire.AchievementProgress>();
    final api = FakeBacklogApi()..onAchievements = (_) => pending.future;

    await pumpSection(tester, api, settle: false);

    expect(find.byKey(const Key('achievements-loading')), findsOneWidget);
    pending.complete(
      const wire.AchievementProgress(unlocked: 0, total: 0, achievements: []),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('shows nothing without a Steam App ID', (tester) async {
    final api = FakeBacklogApi();

    await pumpSection(tester, api, steamAppId: null);

    expect(find.byKey(const Key('achievements')), findsNothing);
    expect(api.calls.where((c) => c.startsWith('achievements')), isEmpty);
  });

  testWidgets('shows nothing for a game without achievements', (tester) async {
    final api = FakeBacklogApi()
      ..onAchievements = (_) async => const wire.AchievementProgress(
        unlocked: 0,
        total: 0,
        achievements: [],
      );

    await pumpSection(tester, api);

    expect(find.byKey(const Key('achievements')), findsNothing);
    expect(find.text('Achievements'), findsNothing);
  });

  testWidgets('shows nothing when the request fails', (tester) async {
    final api = FakeBacklogApi()
      ..onAchievements = (_) async => throw Exception('steam is down');

    await pumpSection(tester, api);

    expect(find.byKey(const Key('achievements')), findsNothing);
    expect(find.byKey(const Key('achievements-loading')), findsNothing);
  });

  testWidgets('"Show all achievements" lists them, the locked ones dimmed', (
    tester,
  ) async {
    final api = FakeBacklogApi()
      ..onAchievements = (_) async => const wire.AchievementProgress(
        unlocked: 1,
        total: 2,
        achievements: achievements,
      );
    await pumpSection(tester, api);

    await tester.tap(find.byKey(const Key('show-achievements')));
    await tester.pumpAndSettle();

    expect(find.text('Achievements (1/2)'), findsOneWidget);
    expect(find.text('First blood'), findsOneWidget);
    expect(find.text('Win a fight'), findsOneWidget);
    expect(find.text('Secret'), findsOneWidget);
    expect(find.text('Hidden achievement'), findsOneWidget);
    double opacityOf(String apiname) => tester
        .widget<Opacity>(
          find.ancestor(
            of: find.byKey(Key('achievement-$apiname')),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    expect(opacityOf('ACH_1'), 1);
    expect(opacityOf('ACH_2'), 0.4);
  });

  testWidgets('golden: the achievements sheet', tags: 'golden', (tester) async {
    final api = FakeBacklogApi()
      ..onAchievements = (_) async => const wire.AchievementProgress(
        unlocked: 1,
        total: 2,
        achievements: achievements,
      );
    await pumpSection(tester, api);
    await tester.tap(find.byKey(const Key('show-achievements')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/achievements_sheet.png'),
    );
  });
}
