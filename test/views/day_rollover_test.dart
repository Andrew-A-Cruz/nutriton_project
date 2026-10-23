import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/app.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/providers/infrastructure_providers.dart';
import 'package:nutriton_project/providers/log_providers.dart';
import 'package:nutriton_project/providers/today_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

// Day D is 2026-10-21. Rollover moves the clock to D+1 (2026-10-22).
const _day = '2026-10-21';
const _nextDay = '2026-10-22';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late DateTime now;

  setUp(() async {
    now = DateTime(2026, 10, 21, 23, 59, 30);
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories', 'protein'],
      'goal_calories': 2000.0,
      'goal_protein': 150.0,
      'display_unit': 'g',
    });
  });

  tearDown(() async {
    await db.close();
  });

  /// The app with the clock under the test's control. [now] is read through
  /// a closure, so reassigning it moves the clock.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const MyApp(),
      ),
    );
    await settle(tester);
  }

  /// Pumps the app, runs [body], and always unmounts afterwards. The unmount
  /// is in `finally`, so a failing expectation still disposes the container
  /// and its midnight timer before flutter_test's pending-timer check.
  /// tester cannot be used from a tearDown, so addTearDown is not an option.
  Future<void> withApp(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    await pumpApp(tester);
    try {
      await body();
    } finally {
      await unmount(tester);
    }
  }

  /// The container that backs the running app.
  ProviderContainer appContainer(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MyApp)));

  /// Simulates the app going to the background and coming back. The steps
  /// follow the platform order, because AppLifecycleListener asserts on
  /// invalid transitions (resumed is only valid after inactive).
  Future<void> resume(WidgetTester tester) async {
    const path = [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ];
    for (final state in path) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    await settle(tester);
  }

  Finder headerTitle() => find.descendant(
    of: find.byKey(const Key('date-title')),
    matching: find.byType(Text),
  );

  String headerText(WidgetTester tester) =>
      tester.widget<Text>(headerTitle()).data!;

  Future<void> seedFood() => CatalogRepository(db).createFood(
    name: 'Chicken breast',
    perServing: const Macros(calories: 165, protein: 31, carbs: 0, fat: 3.6),
    servingWeightG: 100,
  );

  Future<List<FoodLogEntry>> entriesOn(String day) async =>
      db.logDao.watchEntriesForDate(day).first;

  /// Adds one serving of chicken through the Add Food flow, as the user would.
  Future<void> logChickenNow(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
    await tester.tap(find.text('Chicken breast'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('log-amount')), '1');
    await settle(tester);
    await tester.tap(find.byKey(const Key('log-food-confirm')));
    await settle(tester);
  }

  testWidgets('the header says Today just before midnight', (tester) async {
    await withApp(tester, () async {
      expect(headerText(tester), 'Today');
    });
  });

  testWidgets(
    'after resuming on the next day the header is still Today and new logs go to the new day',
    (tester) async {
      await withApp(tester, () async {
        await tester.runAsync(seedFood);
        expect(headerText(tester), 'Today');

        // Background overnight, then come back the next morning.
        now = DateTime(2026, 10, 22, 8, 15);
        await resume(tester);

        expect(headerText(tester), 'Today');

        await logChickenNow(tester);

        expect(headerText(tester), 'Today');
        expect(find.text('Chicken breast'), findsOneWidget);
        final next = await tester.runAsync(() => entriesOn(_nextDay));
        final old = await tester.runAsync(() => entriesOn(_day));
        expect(next!.map((e) => e.name), ['Chicken breast']);
        expect(old, isEmpty);
      });
    },
  );

  testWidgets(
    'the midnight timer moves today and the selected day forward without a resume',
    (tester) async {
      await withApp(tester, () async {
        final container = appContainer(tester);
        expect(container.read(todayProvider), _day);
        expect(container.read(selectedDateProvider), _day);

        // The timer was armed for the 30 s left before midnight.
        now = DateTime(2026, 10, 22, 0, 0, 1);
        await tester.pump(const Duration(seconds: 31));
        await settle(tester);

        expect(container.read(todayProvider), _nextDay);
        expect(container.read(selectedDateProvider), _nextDay);
        expect(headerText(tester), 'Today');
      });
    },
  );

  testWidgets('a day the user navigated to keeps its place after rollover', (
    tester,
  ) async {
    await withApp(tester, () async {
      // Viewing yesterday (D-1); it stays put and is labelled "Yesterday".
      await tester.tap(find.byKey(const Key('previous-day')));
      await settle(tester);
      expect(headerText(tester), 'Yesterday');

      now = DateTime(2026, 10, 22, 8, 15);
      await resume(tester);

      // D-1 is now two days ago, so it is labelled with its date.
      expect(headerText(tester), 'Tue, Oct 20');
      expect(appContainer(tester).read(selectedDateProvider), '2026-10-20');
    });
  });

  testWidgets('Copy yesterday is offered on an empty new day after rollover', (
    tester,
  ) async {
    await tester.runAsync(
      () => LogRepository(db).logAdhoc(
        logDate: _day,
        name: 'Lunch',
        macros: const Macros(calories: 1000, protein: 40, carbs: 90, fat: 20),
      ),
    );
    await withApp(tester, () async {
      expect(find.text('Lunch'), findsOneWidget);

      now = DateTime(2026, 10, 22, 8, 15);
      await resume(tester);

      // The new today has nothing logged, and yesterday has Lunch.
      expect(headerText(tester), 'Today');
      expect(find.text('Nothing logged yet'), findsOneWidget);
      expect(find.byKey(const Key('copy-previous-day')), findsOneWidget);
      expect(find.text('Copy yesterday'), findsOneWidget);
    });
  });

  testWidgets('Summary end date moves to the new today after rollover', (
    tester,
  ) async {
    await tester.runAsync(
      () => LogRepository(db).logAdhoc(
        logDate: _day,
        name: 'Lunch',
        macros: const Macros(calories: 1000, protein: 40, carbs: 90, fat: 20),
      ),
    );
    await withApp(tester, () async {
      await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
      await settle(tester);
      await tester.tap(find.text('Day').last);
      await settle(tester);

      expect(find.text('Days logged: 1 of 1'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('average-calories'))).data,
        '1000 kcal',
      );

      now = DateTime(2026, 10, 22, 8, 15);
      await resume(tester);

      // The end date is now D+1, which has nothing logged.
      expect(find.text('Days logged: 0 of 1'), findsOneWidget);
      expect(find.text('Nothing logged in this period.'), findsOneWidget);
    });
  });
}
