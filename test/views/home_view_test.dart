import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late String today;
  late String yesterday;

  setUp(() async {
    today = todayKey();
    yesterday = addDays(today, -1);
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

  /// Today: 1.5 servings of chicken (247.5 kcal, 46.5 g protein) and a
  /// 200 kcal bar (20 g protein). Yesterday: one oatmeal (300 kcal).
  Future<void> seedDay() async {
    final catalog = CatalogRepository(db);
    final log = LogRepository(db);
    final chickenId = await catalog.createFood(
      name: 'Chicken breast',
      perServing: const Macros(calories: 165, protein: 31, carbs: 0, fat: 3.6),
      servingWeightG: 100,
    );
    final chicken = (await catalog.findFood(chickenId))!;
    await log.logFood(logDate: today, food: chicken, servings: 1.5);
    await log.logAdhoc(
      logDate: today,
      name: 'Protein bar',
      macros: const Macros(calories: 200, protein: 20, carbs: 22, fat: 7),
    );
    await log.logAdhoc(
      logDate: yesterday,
      name: 'Oatmeal',
      macros: const Macros(calories: 300, protein: 10, carbs: 50, fat: 5),
    );
  }

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
  }

  testWidgets('shows the empty state when nothing is logged', (tester) async {
    await pumpHome(tester);

    expect(find.text('Nothing logged yet'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('0'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("shows today's entries and totals, with progress to the goal", (
    tester,
  ) async {
    await tester.runAsync(seedDay);
    await pumpHome(tester);

    expect(find.text('Chicken breast'), findsOneWidget);
    expect(find.text('1.5 servings'), findsOneWidget);
    expect(find.text('Protein bar'), findsOneWidget);
    expect(find.text('Oatmeal'), findsNothing);

    // 447.5 kcal (247.5 + 200) against the 2000 kcal goal, shown rounded.
    expect(
      tester.widget<Text>(find.byKey(const Key('primary-amount'))).data,
      '448',
    );
    expect(find.text('1553 kcal left'), findsOneWidget);
    // 46.5 + 20 g protein against a 150 g goal.
    expect(
      tester
          .widget<Text>(find.byKey(const Key('secondary-amount-protein')))
          .data,
      '66.5 / 150.0 g',
    );
    await unmount(tester);
  });

  testWidgets(
    'previous day shows that day; tapping the title returns to today',
    (tester) async {
      await tester.runAsync(seedDay);
      await pumpHome(tester);

      await tester.tap(find.byKey(const Key('previous-day')));
      await settle(tester);

      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Oatmeal'), findsOneWidget);
      expect(find.text('Protein bar'), findsNothing);

      await tester.tap(find.byKey(const Key('date-title')));
      await settle(tester);

      expect(find.text('Protein bar'), findsOneWidget);
      expect(find.text('Oatmeal'), findsNothing);
      await unmount(tester);
    },
  );

  testWidgets('swiping an entry deletes it from the log', (tester) async {
    await tester.runAsync(seedDay);
    await pumpHome(tester);

    await tester.drag(find.text('Protein bar'), const Offset(-500, 0));
    await tester.pump();
    // The delete runs in the fake-async zone, so it needs a second round of
    // pumping before the database can see it.
    await settle(tester);
    await settle(tester);

    expect(find.text('Protein bar'), findsNothing);
    expect(find.text('Chicken breast'), findsOneWidget);

    final remaining = await tester.runAsync(
      () => db.logDao.watchEntriesForDate(today).first,
    );
    expect(remaining!.map((e) => e.name), ['Chicken breast']);
    await unmount(tester);
  });

  testWidgets('tapping a food entry edits its servings', (tester) async {
    await tester.runAsync(seedDay);
    await pumpHome(tester);

    await tester.tap(find.text('Chicken breast'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('servings-field')), '2');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('2 servings'), findsOneWidget);
    final entries = await tester.runAsync(
      () => db.logDao.watchEntriesForDate(today).first,
    );
    final chicken = entries!.firstWhere((e) => e.name == 'Chicken breast');
    expect(chicken.servings, 2);
    expect(chicken.calories, closeTo(330, 1e-9));
    await unmount(tester);
  });

  testWidgets('the servings dialog rejects non-finite input', (tester) async {
    await tester.runAsync(seedDay);
    await pumpHome(tester);

    await tester.tap(find.text('Chicken breast'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('servings-field')), 'Infinity');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('Enter a number'), findsOneWidget);
    final entries = await tester.runAsync(
      () => db.logDao.watchEntriesForDate(today).first,
    );
    final chicken = entries!.firstWhere((e) => e.name == 'Chicken breast');
    expect(chicken.servings, 1.5);
    expect(chicken.calories, closeTo(247.5, 1e-9));
    await unmount(tester);
  });

  testWidgets('tapping a meal entry shows its breakdown', (tester) async {
    await tester.runAsync(() async {
      final catalog = CatalogRepository(db);
      final log = LogRepository(db);
      final chickenId = await catalog.createFood(
        name: 'Chicken breast',
        perServing: const Macros(
          calories: 165,
          protein: 31,
          carbs: 0,
          fat: 3.6,
        ),
        servingWeightG: 100,
      );
      final mealId = await catalog.createMeal(
        name: 'Lunch bowl',
        items: [MealItemInput(foodItemId: chickenId, weightG: 150)],
      );
      final meal = (await catalog.findMeal(mealId))!;
      await log.logMeal(
        logDate: today,
        meal: meal,
        items: [MealItemInput(foodItemId: chickenId, weightG: 150)],
      );
    });
    await pumpHome(tester);

    await tester.tap(find.text('Lunch bowl'));
    await settle(tester);

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('150 g'), findsOneWidget);
    expect(find.text('Chicken breast'), findsOneWidget);
    await unmount(tester);
  });
}
