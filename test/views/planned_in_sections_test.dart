import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/meal_slot.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/data/repositories/schedule_repository.dart';
import 'package:nutriton_project/views/catalog/food_form_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

/// Planned foods and meals (M17): the Schedule... flow on a food, and planned
/// items as dimmed rows inside their meal section on Home.
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late String today;
  late String foodId;
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
    foodId = await catalog.createFood(
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

  String primary(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('primary-amount'))).data!;

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
  }

  group('the Schedule... flow on a food', () {
    testWidgets('saves a repeating food plan with slot and servings', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final food = (await tester.runAsync(
        () => CatalogRepository(db).findFood(foodId),
      ))!;
      await tester.pumpWidget(
        testScreen(
          db: db,
          prefs: prefs,
          home: RouteHost(route: (_) => FoodFormView(existing: food)),
        ),
      );
      await tester.tap(find.byKey(const Key('open-route')));
      await settle(tester);

      final scheduleRow = find.byKey(const Key('food-schedule'));
      await tester.scrollUntilVisible(
        scheduleRow,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(scheduleRow);
      await settle(tester);

      expect(find.text('Rice'), findsWidgets);
      await tester.tap(find.text('Repeat weekly'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('weekday-5'))); // drop Friday
      await tester.pump();
      final slotPicker = find.byKey(const Key('meal-slot-picker'));
      await tester.ensureVisible(slotPicker);
      await tester.tap(find.text('Dinner'));
      await tester.pump();
      final servings = find.byKey(const Key('schedule-servings'));
      await tester.ensureVisible(servings);
      await tester.enterText(servings, '2');
      await tester.tap(find.byKey(const Key('schedule-save')));
      await settle(tester);

      final plans = (await tester.runAsync(
        () => db.scheduledMealDao.findSchedulesForFood(foodId),
      ))!;
      final plan = plans.single;
      expect(plan.mealId, isNull);
      expect(plan.weekdays, 0x0F); // Mon-Thu
      expect(plan.mealSlot, 'dinner');
      expect(plan.servings, 2);
      expect(plan.startDate, today);
      await unmount(tester);
    });

    testWidgets('refuses servings that are not a positive number', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final food = (await tester.runAsync(
        () => CatalogRepository(db).findFood(foodId),
      ))!;
      await tester.pumpWidget(
        testScreen(
          db: db,
          prefs: prefs,
          home: RouteHost(route: (_) => FoodFormView(existing: food)),
        ),
      );
      await tester.tap(find.byKey(const Key('open-route')));
      await settle(tester);
      final scheduleRow = find.byKey(const Key('food-schedule'));
      await tester.scrollUntilVisible(
        scheduleRow,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(scheduleRow);
      await settle(tester);

      final servings = find.byKey(const Key('schedule-servings'));
      await tester.ensureVisible(servings);
      await tester.enterText(servings, '0');
      await tester.tap(find.byKey(const Key('schedule-save')));
      await settle(tester);

      expect(find.text('Enter a number greater than 0'), findsOneWidget);
      final plans = (await tester.runAsync(
        () => db.scheduledMealDao.findSchedulesForFood(foodId),
      ))!;
      expect(plans, isEmpty);
      await unmount(tester);
    });
  });

  group('planned rows on Home', () {
    Future<String> planFood({MealSlot? slot, double servings = 1}) =>
        ScheduleRepository(db).scheduleOnce(
          foodItemId: foodId,
          date: today,
          mealSlot: slot,
          servings: servings,
        );

    testWidgets('sit dimmed inside their section and count toward nothing', (
      tester,
    ) async {
      final id = (await tester.runAsync(() async {
        await LogRepository(db).logAdhoc(
          logDate: today,
          name: 'Oatmeal',
          macros: const Macros(calories: 300, protein: 1, carbs: 1, fat: 1),
          mealSlot: MealSlot.breakfast,
        );
        return ScheduleRepository(db).scheduleOnce(
          foodItemId: foodId,
          date: today,
          mealSlot: MealSlot.lunch,
          servings: 2,
        );
      }))!;
      await pumpHome(tester);

      // Its own section, with the plan below the header and no separate block.
      final header = find.byKey(const Key('section-lunch'));
      final row = find.byKey(Key('planned-tile-$id'));
      expect(header, findsOneWidget);
      expect(row, findsOneWidget);
      expect(find.byKey(const Key('scheduled-suggestions')), findsNothing);
      expect(
        tester.getTopLeft(row).dy,
        greaterThan(tester.getTopLeft(header).dy),
      );
      expect(
        tester.getTopLeft(row).dy,
        greaterThan(tester.getTopLeft(find.text('Oatmeal')).dy),
      );
      expect(find.text('Rice'), findsOneWidget);
      expect(find.textContaining('2 servings'), findsOneWidget);
      // Dimmed.
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: row, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, lessThan(1));
      // A section holding only a suggestion shows no calorie total.
      expect(find.byKey(const Key('section-total-lunch')), findsNothing);
      expect(find.byKey(const Key('section-total-breakfast')), findsOneWidget);
      // Not in the totals, the streak or the log.
      expect(primary(tester), '300');
      expect(await entriesToday(tester), hasLength(1));
      // And the empty state does not apply.
      expect(find.text('Nothing logged yet'), findsNothing);
      await unmount(tester);
    });

    testWidgets('a plan without a slot is filed by the time of day', (
      tester,
    ) async {
      await tester.runAsync(() => planFood());
      await pumpHome(tester);
      final slot = MealSlot.forTime(DateTime.now());
      expect(find.byKey(Key('section-${slot.name}')), findsOneWidget);
      expect(find.byKey(const Key('section-other')), findsNothing);
      await unmount(tester);
    });

    testWidgets('only planned items: no empty state, nothing counted', (
      tester,
    ) async {
      await tester.runAsync(() => planFood(slot: MealSlot.snack));
      await pumpHome(tester);
      expect(find.text('Nothing logged yet'), findsNothing);
      expect(find.text('Rice'), findsOneWidget);
      expect(primary(tester), '0');
      expect(find.byKey(const Key('streak-badge')), findsNothing);
      expect(await entriesToday(tester), isEmpty);
      await unmount(tester);
    });

    testWidgets('tap logs the plan into its section with its servings', (
      tester,
    ) async {
      final id = (await tester.runAsync(
        () => planFood(slot: MealSlot.lunch, servings: 2),
      ))!;
      await pumpHome(tester);

      await tester.tap(find.byKey(Key('planned-tile-$id')));
      await settle(tester);

      final entry = (await entriesToday(tester)).single;
      expect(entry.entryType, 'food');
      expect(entry.foodItemId, foodId);
      expect(entry.servings, 2);
      expect(entry.mealSlot, 'lunch');
      expect(entry.calories, closeTo(260, 1e-9));
      // The suggestion is replaced by the real entry, now counted.
      expect(find.byKey(Key('planned-tile-$id')), findsNothing);
      expect(find.byKey(const Key('section-total-lunch')), findsOneWidget);
      expect(primary(tester), '260');
      final outcome = (await tester.runAsync(
        () => db.scheduledMealDao.findOutcomes(id),
      ))!;
      expect(outcome.single.status, 'logged');
      expect(outcome.single.entryId, entry.id);
      await unmount(tester);
    });

    testWidgets('a planned meal logs as a meal when tapped', (tester) async {
      final id = (await tester.runAsync(
        () => ScheduleRepository(
          db,
        ).scheduleOnce(mealId: mealId, date: today, mealSlot: MealSlot.dinner),
      ))!;
      await pumpHome(tester);
      expect(find.text('Lunch bowl'), findsOneWidget);

      await tester.tap(find.byKey(Key('planned-tile-$id')));
      await settle(tester);

      final entry = (await entriesToday(tester)).single;
      expect(entry.entryType, 'meal');
      expect(entry.mealSlot, 'dinner');
      await unmount(tester);
    });

    testWidgets('swipe skips it for the day without logging', (tester) async {
      final id = (await tester.runAsync(
        () => ScheduleRepository(db).scheduleWeekdays(
          foodItemId: foodId,
          startDate: today,
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          mealSlot: MealSlot.lunch,
        ),
      ))!;
      await pumpHome(tester);

      await tester.drag(
        find.byKey(Key('planned-tile-$id')),
        const Offset(-500, 0),
      );
      await settle(tester);

      expect(find.byKey(Key('planned-tile-$id')), findsNothing);
      expect(find.byKey(const Key('section-lunch')), findsNothing);
      expect(await entriesToday(tester), isEmpty);
      final outcome = (await tester.runAsync(
        () => db.scheduledMealDao.findOutcomes(id),
      ))!;
      expect(
        (outcome.single.status, outcome.single.date),
        ('dismissed', today),
      );
      // The repeating plan itself is untouched and returns tomorrow.
      final tomorrow = addDays(today, 1);
      final next = (await tester.runAsync(
        () => ScheduleRepository(db).watchPendingForDate(tomorrow).first,
      ))!;
      expect(next, hasLength(1));
      await unmount(tester);
    });

    testWidgets('long-press offers to stop a repeating plan', (tester) async {
      final id = (await tester.runAsync(
        () => ScheduleRepository(db).scheduleWeekdays(
          foodItemId: foodId,
          startDate: today,
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          mealSlot: MealSlot.lunch,
        ),
      ))!;
      await pumpHome(tester);

      await tester.longPress(find.byKey(Key('planned-tile-$id')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('planned-stop-repeating')));
      await settle(tester);

      expect(find.byKey(Key('planned-tile-$id')), findsNothing);
      final plan = await tester.runAsync(
        () => db.scheduledMealDao.findSchedule(id),
      );
      expect(plan, isNull);
      await unmount(tester);
    });

    testWidgets('archived sources are not suggested', (tester) async {
      await tester.runAsync(() async {
        await planFood(slot: MealSlot.lunch);
        await CatalogRepository(db).setFoodArchived(foodId, archived: true);
      });
      await pumpHome(tester);
      expect(find.text('Rice'), findsNothing);
      expect(find.byKey(const Key('section-lunch')), findsNothing);
      await unmount(tester);
    });
  });
}
