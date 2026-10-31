import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/design/background_motion.dart';
import 'package:backlog_manager/design/glass.dart';
import 'package:backlog_manager/design/light_effects.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the app opens at sign-in', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BacklogManagerApp()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('page-sign-in')), findsOneWidget);
  });

  testWidgets('the app uses the Shelf OLED theme by default', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BacklogManagerApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byKey(const Key('page-sign-in')));
    final tokens = Theme.of(context).extension<ShelfTokens>()!;

    expect(tokens.accent, const Color(0xFFF5A524));
    expect(Theme.of(context).scaffoldBackgroundColor, const Color(0xFF000000));
  });

  testWidgets('the glass blurs behind the window by default', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BacklogManagerApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byKey(const Key('page-sign-in')));
    expect(AtmosphereSettings.blurEnabledOf(context), isTrue);
  });

  testWidgets('the glass stays flat when the blur effects are off', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [blurEffectsProvider.overrideWith(_NoBlur.new)],
        child: const BacklogManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byKey(const Key('page-sign-in')));
    expect(AtmosphereSettings.blurEnabledOf(context), isFalse);
  });

  testWidgets('the glass stays flat while the effects are lightened', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lightEffectsProvider.overrideWithValue(LightEffectsReason.powerSave),
        ],
        child: const BacklogManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byKey(const Key('page-sign-in')));
    expect(AtmosphereSettings.blurEnabledOf(context), isFalse);
  });

  testWidgets('large system text sizes stay within what the layouts hold', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const ProviderScope(child: BacklogManagerApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byKey(const Key('page-sign-in')));
    expect(MediaQuery.textScalerOf(context).scale(10), closeTo(13, 0.01));
  });

  testWidgets('a slightly larger text size is kept as it is', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.15;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const ProviderScope(child: BacklogManagerApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byKey(const Key('page-sign-in')));
    expect(MediaQuery.textScalerOf(context).scale(10), closeTo(11.5, 0.01));
  });
}

class _NoBlur extends BackgroundMotionNotifier {
  _NoBlur() : super(blurEffectsStoreProvider);

  @override
  bool build() => false;
}
