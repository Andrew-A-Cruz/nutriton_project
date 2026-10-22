import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/views/tour/app_tour.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  final card = find.byKey(const Key('tour-card'));
  final next = find.byKey(const Key('tour-next'));

  /// Fresh install, through the welcome pages and setup, to the first step.
  Future<void> finishOnboarding(WidgetTester tester) async {
    final prefs = await tester.runAsync(() => mockPreferences({}));
    await tester.pumpWidget(testApp(db: db, prefs: prefs!));
    await settle(tester);
    await skipWelcome(tester);
    await tester.enterText(find.byKey(const Key('goal-calories')), '2000');
    await tapSubmitPreferences(tester);
    await settle(tester);
  }

  testWidgets('Next goes through the welcome pages to setup', (tester) async {
    final prefs = await tester.runAsync(() => mockPreferences({}));
    await tester.pumpWidget(testApp(db: db, prefs: prefs!));
    await settle(tester);

    expect(find.text('Welcome to Nutriton'), findsOneWidget);
    await tester.tap(find.byKey(const Key('welcome-next')));
    await settle(tester);
    expect(find.text('Log in a few taps'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('welcome-next')));
      await settle(tester);
    }
    expect(find.text('Your data stays yours'), findsOneWidget);
    expect(find.text('Set up'), findsOneWidget);

    await tester.tap(find.byKey(const Key('welcome-next')));
    await settle(tester);
    expect(find.text('Set up Nutriton'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('setup can go back to the welcome pages', (tester) async {
    final prefs = await tester.runAsync(() => mockPreferences({}));
    await tester.pumpWidget(testApp(db: db, prefs: prefs!));
    await settle(tester);
    await skipWelcome(tester);

    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await settle(tester);

    expect(find.text('Welcome to Nutriton'), findsOneWidget);
    expect(find.text('Set up Nutriton'), findsNothing);
    await unmount(tester);
  });

  testWidgets('finishing setup starts the tour, and Next walks every step', (
    tester,
  ) async {
    await finishOnboarding(tester);

    expect(card, findsOneWidget);
    for (final (i, step) in tourSteps.indexed) {
      expect(find.text('${i + 1} of ${tourSteps.length}'), findsOneWidget);
      // Within the card, since some titles match a tab label.
      expect(
        find.descendant(of: card, matching: find.text(step.title)),
        findsOneWidget,
      );
      await tester.tap(next);
      await settle(tester);
    }

    expect(card, findsNothing);
    expect(find.text('Food Log'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the card sits beside its target', (tester) async {
    await finishOnboarding(tester);

    // Step 1 points at the date near the top, so the card goes below it.
    expect(
      tester.getTopLeft(card).dy,
      greaterThan(tester.getBottomLeft(find.byKey(const Key('date-title'))).dy),
    );

    // The Summary step points at the tab bar, so the card goes above it.
    final summaryStep = tourSteps.indexWhere(
      (s) => s.target == TourTargets.summaryTab,
    );
    for (var i = 0; i < summaryStep; i++) {
      await tester.tap(next);
      await settle(tester);
    }
    expect(
      tester.getBottomLeft(card).dy,
      lessThan(tester.getTopLeft(find.byType(CupertinoTabBar)).dy),
    );
    await unmount(tester);
  });

  testWidgets('Skip ends the tour, and the app underneath works', (
    tester,
  ) async {
    await finishOnboarding(tester);

    // The scrim takes the tap, so Add Food does not open.
    await tester.tap(
      find.byKey(const Key('add-food-button')),
      warnIfMissed: false,
    );
    await settle(tester);
    expect(find.text('Add Food'), findsNothing);

    await tester.tap(find.byKey(const Key('tour-skip')));
    await settle(tester);
    expect(card, findsNothing);

    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
    expect(find.text('Add Food'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('existing users do not see the tour on launch', (tester) async {
    final prefs = await tester.runAsync(
      () => mockPreferences({'onboarding_complete': true}),
    );
    await tester.pumpWidget(testApp(db: db, prefs: prefs!));
    await settle(tester);

    expect(find.byType(CupertinoTabScaffold), findsOneWidget);
    expect(card, findsNothing);
    await unmount(tester);
  });

  testWidgets('Settings replays the tour back on Today', (tester) async {
    final prefs = await tester.runAsync(
      () => mockPreferences({
        'onboarding_complete': true,
        'goal_calories': 2000.0,
      }),
    );
    await tester.pumpWidget(testApp(db: db, prefs: prefs!));
    await settle(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    // Help is just above the submit button, clear of the tab bar.
    await scrollPreferencesToEnd(tester);
    await tester.tap(find.byKey(const Key('show-tour')));
    await settle(tester);

    expect(find.text('Settings'), findsNothing);
    expect(card, findsOneWidget);
    expect(find.text(tourSteps.first.title), findsOneWidget);
    await unmount(tester);
  });
}
