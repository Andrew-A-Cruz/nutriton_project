import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/schedule_repository.dart';
import 'package:nutriton_project/views/meals/schedule_meal_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late String today;
  late String mealId;

  setUp(() async {
    today = todayKey();
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'display_unit': 'g',
    });
    final catalog = CatalogRepository(db);
    final foodId = await catalog.createFood(
      name: 'Rice',
      perServing: const Macros(calories: 130, protein: 3, carbs: 28, fat: 0.3),
      servingWeightG: 100,
    );
    mealId = await catalog.createMeal(
      name: 'Lunch bowl',
      items: [MealItemInput(foodItemId: foodId, weightG: 100)],
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<FoodLogEntry>> entriesToday(WidgetTester tester) async =>
      (await tester.runAsync(() => db.logDao.findEntriesForDate(today)))!;

  testWidgets('Home suggests a planned meal; tapping it logs it', (
    tester,
  ) async {
    final id = await tester.runAsync(
      () => ScheduleRepository(db).scheduleOnce(mealId: mealId, date: today),
    );
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);

    expect(find.byKey(Key('planned-tile-$id')), findsOneWidget);
    expect(find.text('Lunch bowl'), findsOneWidget);
    // Suggested, not logged.
    expect(await entriesToday(tester), isEmpty);

    await tester.tap(find.byKey(Key('planned-tile-$id')));
    await settle(tester);

    expect(find.byKey(Key('planned-tile-$id')), findsNothing);
    final after = await entriesToday(tester);
    expect(after.single.name, 'Lunch bowl');
    expect(after.single.calories, 130);
    expect(find.text('Lunch bowl'), findsOneWidget); // now in the log
    await unmount(tester);
  });

  testWidgets('Swiping a suggestion hides it without logging', (tester) async {
    final id = await tester.runAsync(
      () => ScheduleRepository(db).scheduleOnce(mealId: mealId, date: today),
    );
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);

    await tester.drag(
      find.byKey(Key('planned-tile-$id')),
      const Offset(-500, 0),
    );
    await settle(tester);

    expect(find.byKey(Key('planned-tile-$id')), findsNothing);
    expect(await entriesToday(tester), isEmpty);
    await unmount(tester);
  });

  testWidgets('long-pressing a repeating plan offers skip or stop', (
    tester,
  ) async {
    final id = await tester.runAsync(
      () => ScheduleRepository(db).scheduleWeekdays(
        mealId: mealId,
        startDate: today,
        weekdays: {1, 2, 3, 4, 5, 6, 7},
      ),
    );
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);

    await tester.longPress(find.byKey(Key('planned-tile-$id')));
    await settle(tester);
    expect(find.byKey(const Key('planned-skip-day')), findsOneWidget);
    await tester.tap(find.byKey(const Key('planned-stop-repeating')));
    await settle(tester);

    expect(find.byKey(Key('planned-tile-$id')), findsNothing);
    final plan = await tester.runAsync(
      () => db.scheduledMealDao.findSchedule(id!),
    );
    expect(plan, isNull);
    await unmount(tester);
  });

  Future<void> openSchedule(WidgetTester tester) async {
    final meal = (await tester.runAsync(
      () => CatalogRepository(db).findMeal(mealId),
    ))!;
    await tester.pumpWidget(
      testScreen(
        db: db,
        prefs: prefs,
        home: RouteHost(
          route: (_) => ScheduleMealView(meal: meal, initialDate: today),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-route')));
    await settle(tester);
  }

  testWidgets('Schedule screen saves a one-off plan', (tester) async {
    await openSchedule(tester);
    await tester.tap(find.byKey(const Key('schedule-save')));
    await settle(tester);

    final plans = await tester.runAsync(
      () => db.scheduledMealDao.findSchedulesForMeal(mealId),
    );
    expect(plans!.single.startDate, today);
    expect(plans.single.weekdays, isNull);
    await unmount(tester);
  });

  testWidgets('Schedule screen repeats Mon-Fri by default, toggles days', (
    tester,
  ) async {
    await openSchedule(tester);
    await tester.tap(find.text('Repeat weekly'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('weekday-5'))); // drop Friday
    await tester.pump();
    await tester.tap(find.byKey(const Key('schedule-save')));
    await settle(tester);

    final plans = await tester.runAsync(
      () => db.scheduledMealDao.findSchedulesForMeal(mealId),
    );
    expect(plans!.single.weekdays, 0x0F); // Mon-Thu
    await unmount(tester);
  });

  testWidgets('Schedule screen refuses an empty weekday set', (tester) async {
    await openSchedule(tester);
    await tester.tap(find.text('Repeat weekly'));
    await settle(tester);
    for (var d = 1; d <= 5; d++) {
      await tester.tap(find.byKey(Key('weekday-$d')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('schedule-save')));
    await settle(tester);

    expect(find.text('Pick at least one day'), findsOneWidget);
    final plans = await tester.runAsync(
      () => db.scheduledMealDao.findSchedulesForMeal(mealId),
    );
    expect(plans, isEmpty);
    await unmount(tester);
  });
}
